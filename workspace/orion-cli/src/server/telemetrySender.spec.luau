local test = require("@std/test")

local appendQueue = require("@root/telemetry/appendQueue")
local getBuild = require("@root/telemetry/getBuild")
local takeQueue = require("@root/telemetry/takeQueue")
local telemetrySender = require("@root/server/telemetrySender")
local telemetryTypes = require("@root/telemetry/types")
local testing = require("@root/testing")
local writeConsent = require("@root/telemetry/writeConsent")

type Build = telemetryTypes.Build
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

	appendQueue(root, events)
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
		): boolean
			table.insert(sent, { endpoint = endpoint, installId = installId, build = build, count = #events })
			return isAccepted
		end
end

test.case("an opted-in machine sends its queue in batches and empties it", function(assert)
	local root = testing.directory("sender-send")
	local consent = writeConsent(root, true)
	queue(root, 150)
	local sent, send = createFake(true)

	local sender = telemetrySender.create(root, { environment = {}, build = RELEASE, sendBatchAsync = send })

	assert.eq(sender.flushAsync(), 150)
	assert.eq(#sent, 2)
	assert.eq(sent[1].endpoint, "https://api.oriongraph.app/telemetry/v1/events")
	assert.eq(sent[1].installId, consent.installId)
	assert.eq(sent[1].build.channel, "release")
	assert.eq(sent[2].count, 50)
	assert.eq(#takeQueue(root, NOW), 0)
end)

test.case("a batch that fails is dropped, not retried", function(assert)
	local root = testing.directory("sender-fail")
	writeConsent(root, true)
	queue(root, 3)
	local sent, send = createFake(false)
	local sender = telemetrySender.create(root, { environment = {}, build = RELEASE, sendBatchAsync = send })

	assert.eq(sender.flushAsync(), 0)
	assert.eq(sender.flushAsync(), 0)
	assert.eq(#sent, 1)
end)

test.case("the queue is dropped unsent when sending isn't allowed", function(assert)
	local cases: { QuietCase } = {
		{ name = "opted out", consent = false, environment = {}, build = RELEASE },
		{ name = "override", consent = true, environment = { ORION_TELEMETRY = "0" }, build = RELEASE },
		{ name = "dev build", consent = true, environment = {}, build = getBuild("dev") },
		{ name = "CI", consent = true, environment = { CI = "true" }, build = RELEASE },
		{ name = "dev server", consent = true, environment = {}, build = RELEASE, isDevServer = true },
	}

	for _, case in cases do
		local root = testing.directory(`sender-quiet-{case.name}`)
		writeConsent(root, case.consent)
		queue(root, 2)
		local sent, send = createFake(true)
		local sender = telemetrySender.create(root, {
			environment = case.environment,
			build = case.build,
			isDevServer = case.isDevServer,
			sendBatchAsync = send,
		})

		assert.eq(sender.flushAsync(), 0)
		assert.eq(#sent, 0)
		assert.eq(#takeQueue(root, NOW), 0)
	end
end)

test.case("ORION_TELEMETRY_ENDPOINT points batches at another backend", function(assert)
	local root = testing.directory("sender-endpoint")
	writeConsent(root, true)
	queue(root, 1)
	local sent, send = createFake(true)
	local sender = telemetrySender.create(root, {
		environment = { ORION_TELEMETRY_ENDPOINT = "http://127.0.0.1:3000/telemetry/v1/events" },
		build = RELEASE,
		sendBatchAsync = send,
	})

	sender.flushAsync()

	assert.eq(sent[1].endpoint, "http://127.0.0.1:3000/telemetry/v1/events")
end)
