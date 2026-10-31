local test = require("@std/test")

local appendTelemetryQueue = require("@root/telemetry/appendTelemetryQueue")
local drainTelemetryQueue = require("@root/telemetry/drainTelemetryQueue")
local getBuild = require("@root/getBuild")
local telemetrySender = require("@root/server/telemetrySender")
local telemetryTypes = require("@root/telemetry/types")
local testing = require("@root/testing")
local types = require("@root/types")
local writeTelemetryConsent = require("@root/telemetry/writeTelemetryConsent")

type Build = types.Build
type TelemetryConfig = telemetryTypes.TelemetryConfig
type QueuedEvent = telemetryTypes.QueuedEvent

type Sent = { endpoint: string, installId: string, build: Build, count: number }

type QuietCase = {
	name: string,
	consent: boolean,
	environment: { [string]: string },
	build: Build,
	isDevServer: boolean?,
}

local NOW = "2026-10-30T12:00:00Z"
local RELEASE = getBuild("e87813e")

local function queue(root: string, count: number)
	local events: { QueuedEvent } = {}

	for _ = 1, count do
		table.insert(events, { name = "cli_command_ran", timestamp = NOW, properties = { command = "card set" } })
	end

	appendTelemetryQueue(root, events)
end

local function createFake(isAccepted: boolean)
	local sent: { Sent } = {}

	return sent,
		function(
			endpoint: string,
			installId: string,
			build: Build,
			events: { QueuedEvent },
			_timeoutSeconds: number
		): (boolean, string?)
			table.insert(sent, { endpoint = endpoint, installId = installId, build = build, count = #events })
			return isAccepted, if isAccepted then nil else "the backend answered 500"
		end
end

-- A backend whose config can't be reached, so the built-in limits apply.
local function offlineConfigAsync(_endpoint: string, _timeoutSeconds: number): (TelemetryConfig?, string?)
	return nil, "the backend answered 503"
end

test.case("an opted-in machine sends its queue in batches and empties it", function(assert)
	local root = testing.directory("sender-send")
	local consent = writeTelemetryConsent(root, true)
	queue(root, 150)
	local sent, send = createFake(true)

	local sender = telemetrySender.create(root, {
		environment = {},
		build = RELEASE,
		sendTelemetryBatchAsync = send,
		getTelemetryConfigAsync = offlineConfigAsync,
	})

	assert.eq(sender.flushAsync(), 150)
	assert.eq(#sent, 2)
	assert.eq(sent[1].endpoint, "https://api.oriongraph.app/telemetry/v1/events")
	assert.eq(sent[1].installId, consent.installId)
	assert.eq(sent[1].build.channel, "release")
	assert.eq(sent[2].count, 50)
	assert.eq(#drainTelemetryQueue(root, NOW), 0)
end)

test.case("a batch that fails is dropped, not retried", function(assert)
	local root = testing.directory("sender-fail")
	writeTelemetryConsent(root, true)
	queue(root, 3)
	local sent, send = createFake(false)
	local sender = telemetrySender.create(root, {
		environment = {},
		build = RELEASE,
		sendTelemetryBatchAsync = send,
		getTelemetryConfigAsync = offlineConfigAsync,
	})

	assert.eq(sender.flushAsync(), 0)
	assert.eq(sender.flushAsync(), 0)
	assert.eq(#sent, 1)
end)

test.case("the queue is dropped unsent when sending isn't allowed", function(assert)
	local cases: { QuietCase } = {
		{ name = "opted out", consent = false, environment = {}, build = RELEASE },
		{ name = "override", consent = true, environment = { ORION_TELEMETRY = "0" }, build = RELEASE },
		{ name = "dev build", consent = true, environment = {}, build = getBuild("dev") },
		{ name = "build outside git", consent = true, environment = {}, build = getBuild("unknown") },
		{ name = "CI", consent = true, environment = { CI = "true" }, build = RELEASE },
		{ name = "dev server", consent = true, environment = {}, build = RELEASE, isDevServer = true },
	}

	for _, case in cases do
		local root = testing.directory(`sender-quiet-{case.name}`)
		writeTelemetryConsent(root, case.consent)
		queue(root, 2)
		local sent, send = createFake(true)
		local sender = telemetrySender.create(root, {
			environment = case.environment,
			build = case.build,
			isDevServer = case.isDevServer,
			sendTelemetryBatchAsync = send,
			getTelemetryConfigAsync = offlineConfigAsync,
		})

		assert.eq(sender.flushAsync(), 0)
		assert.eq(#sent, 0)
		assert.eq(#drainTelemetryQueue(root, NOW), 0)
	end
end)

test.case("ORION_TELEMETRY_URL points the sender at another backend", function(assert)
	local root = testing.directory("sender-endpoint")
	writeTelemetryConsent(root, true)
	queue(root, 1)
	local sent, send = createFake(true)
	local sender = telemetrySender.create(root, {
		environment = { ORION_TELEMETRY_URL = "http://127.0.0.1:3000/telemetry/v1" },
		build = RELEASE,
		sendTelemetryBatchAsync = send,
		getTelemetryConfigAsync = offlineConfigAsync,
	})

	sender.flushAsync()

	assert.eq(sent[1].endpoint, "http://127.0.0.1:3000/telemetry/v1/events")
end)

test.case("batches follow the backend's limits, asked for once a run", function(assert)
	local root = testing.directory("sender-limits")
	writeTelemetryConsent(root, true)
	local sent, send = createFake(true)
	local askedAt: { string } = {}
	local sender = telemetrySender.create(root, {
		environment = {},
		build = RELEASE,
		sendTelemetryBatchAsync = send,
		getTelemetryConfigAsync = function(endpoint: string, _timeoutSeconds: number): (TelemetryConfig?, string?)
			table.insert(askedAt, endpoint)
			return { limits = { maxEvents = 40, maxBytes = 64 * 1024 } }, nil
		end,
	})

	queue(root, 100)
	assert.eq(sender.flushAsync(), 100)
	queue(root, 50)
	assert.eq(sender.flushAsync(), 50)

	assert.eq(#sent, 5)
	assert.eq(sent[1].count, 40)
	assert.eq(#askedAt, 1)
	assert.eq(askedAt[1], "https://api.oriongraph.app/telemetry/v1/config")
end)

test.case("without the backend's limits, batches use the built-in ones and the next send asks again", function(assert)
	local root = testing.directory("sender-limits-offline")
	writeTelemetryConsent(root, true)
	local sent, send = createFake(true)
	local asked = 0
	local sender = telemetrySender.create(root, {
		environment = {},
		build = RELEASE,
		sendTelemetryBatchAsync = send,
		getTelemetryConfigAsync = function(endpoint: string, timeoutSeconds: number): (TelemetryConfig?, string?)
			asked += 1
			return offlineConfigAsync(endpoint, timeoutSeconds)
		end,
	})

	queue(root, 150)
	assert.eq(sender.flushAsync(), 150)
	queue(root, 1)
	sender.flushAsync()

	assert.eq(sent[1].count, 100)
	assert.eq(asked, 2)
end)

test.case("opting out partway through a send stops the batches after it", function(assert)
	local root = testing.directory("sender-opt-out")
	writeTelemetryConsent(root, true)
	queue(root, 150)
	local batches = 0
	local sender = telemetrySender.create(root, {
		environment = {},
		build = RELEASE,
		sendTelemetryBatchAsync = function(
			_endpoint: string,
			_installId: string,
			_build: Build,
			_events: { QueuedEvent },
			_timeoutSeconds: number
		): (boolean, string?)
			batches += 1
			writeTelemetryConsent(root, false)
			return true, nil
		end,
		getTelemetryConfigAsync = offlineConfigAsync,
	})

	assert.eq(sender.flushAsync(), 100)
	assert.eq(batches, 1)
end)

test.case("a send stops at the batches the backend accepts in a minute and keeps the rest", function(assert)
	local root = testing.directory("sender-batch-cap")
	writeTelemetryConsent(root, true)
	queue(root, 30)
	local sent, send = createFake(true)
	local sender = telemetrySender.create(root, {
		environment = {},
		build = RELEASE,
		sendTelemetryBatchAsync = send,
		getTelemetryConfigAsync = function(_endpoint: string, _timeoutSeconds: number): (TelemetryConfig?, string?)
			return { limits = { maxEvents = 1, maxBytes = 64 * 1024 } }, nil
		end,
	})

	assert.eq(sender.flushAsync(), 25)
	assert.eq(#sent, 25)
	assert.eq(#drainTelemetryQueue(root, NOW), 5)
end)
