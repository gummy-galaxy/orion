local json = require("@std/json")
local net = require("@lute/net/server")
local process = require("@std/process")

local chooseTelemetry = require("@root/telemetry/chooseTelemetry")
local getTelemetryStatus = require("@root/telemetry/getTelemetryStatus")
local parseTelemetryEvent = require("@root/telemetry/parseTelemetryEvent")
local queueTelemetryEvents = require("@root/telemetry/queueTelemetryEvents")
local serializeTelemetryStatus = require("@root/telemetry/serializeTelemetryStatus")
local shared = require("@root/server/routes/shared")
local telemetryTypes = require("@root/telemetry/types")
local types = require("@root/types")

type Build = types.Build
type QueuedEvent = telemetryTypes.QueuedEvent
type Response = shared.Response

-- The most the app may post at once. Only this route checks them: serve splits
-- what it queues by the backend's own limits, so these needn't match.
local MAX_EVENTS = 100
local MAX_BODY_BYTES = 64 * 1024

local telemetry = {}

-- `GET` returns the status, which the app reads on launch to decide whether to
-- ask. `POST {"enabled": true|false}` records the person's answer from the
-- app's dialog or Settings. The environment is the server's, which the app
-- launched.
function telemetry.handle(
	request: net.ReceivedRequest,
	root: string,
	environment: { [string]: string }?,
	build: Build?
): Response
	local resolvedEnvironment = environment or process.env

	if request.method == "GET" then
		return shared.reply(200, serializeTelemetryStatus(getTelemetryStatus(root, resolvedEnvironment)))
	end

	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local didSucceed, response = pcall(function(): Response
		local enabled = shared.parseBody(request).enabled
		assert(type(enabled) == "boolean", "enabled must be true or false")

		chooseTelemetry(root, enabled, "app", resolvedEnvironment, build)

		return shared.reply(200, serializeTelemetryStatus(getTelemetryStatus(root, resolvedEnvironment)))
	end)

	return if didSucceed then response :: Response else shared.reply(400, json.object({ error = tostring(response) }))
end

-- `POST {"events": [...]}` queues the app's events for the server to send.
-- Only their size and shape are checked; the backend checks them against the
-- catalog. When the machine isn't sharing, the events are dropped and the
-- reply says none were queued, so the app needn't check first.
function telemetry.handleEvents(
	request: net.ReceivedRequest,
	root: string,
	environment: { [string]: string }?,
	build: Build?
): Response
	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	if #request.body > MAX_BODY_BYTES then
		return shared.reply(413, json.object({ error = "a batch is at most 64 KiB" }))
	end

	local didSucceed, response = pcall(function(): Response
		local rawEvents = assert(json.asArray(shared.parseBody(request).events), "events must be an array")

		if #rawEvents > MAX_EVENTS then
			return shared.reply(413, json.object({ error = `a batch holds at most {MAX_EVENTS} events` }))
		end

		local now = os.date("!%Y-%m-%dT%H:%M:%SZ") :: string
		local events: { QueuedEvent } = {}

		for _, rawEvent in rawEvents do
			table.insert(events, parseTelemetryEvent(rawEvent, now))
		end

		local queued = queueTelemetryEvents(root, events, environment or process.env, build)

		return shared.reply(202, json.object({ queued = queued }))
	end)

	return if didSucceed then response :: Response else shared.reply(400, json.object({ error = tostring(response) }))
end

return table.freeze(telemetry)
