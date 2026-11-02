local json = require("@std/json")
local net = require("@lute/net/server")
local process = require("@std/process")

local chooseTelemetry = require("@root/telemetry/chooseTelemetry")
local deleteTelemetryDataAsync = require("@root/telemetry/deleteTelemetryDataAsync")
local formatTimestamp = require("@root/common/time/formatTimestamp")
local getTelemetryStatus = require("@root/telemetry/getTelemetryStatus")
local parseTelemetryEvent = require("@root/telemetry/parseTelemetryEvent")
local queueTelemetryEvents = require("@root/telemetry/queueTelemetryEvents")
local requestTelemetryAsync = require("@root/telemetry/requestTelemetryAsync")
local serializeTelemetryStatus = require("@root/telemetry/serializeTelemetryStatus")
local shared = require("@root/server/routes/shared")
local telemetryConstants = require("@root/telemetry/constants")
local telemetryTypes = require("@root/telemetry/types")
local types = require("@root/types")

type Build = types.Build
type QueuedEvent = telemetryTypes.QueuedEvent
type Response = shared.Response

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

-- `POST {"events": [...]}` queues the app's events for this server to send to
-- the telemetry backend later. Each event must have a valid name, session id,
-- timestamp, and flat properties, but this route doesn't check which events
-- exist. The backend does that against the published event list. When the
-- machine isn't sharing usage data, the events are dropped and the reply says
-- none were queued, so the app can post without checking first.
function telemetry.handleEvents(
	request: net.ReceivedRequest,
	root: string,
	environment: { [string]: string }?,
	build: Build?
): Response
	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	if #request.body > telemetryConstants.MAX_APP_BODY_BYTES then
		return shared.reply(413, json.object({ error = "a batch is at most 64 KiB" }))
	end

	local didSucceed, response = pcall(function(): Response
		local rawEvents = assert(json.asArray(shared.parseBody(request).events), "events must be an array")

		if #rawEvents > telemetryConstants.MAX_APP_EVENTS then
			return shared.reply(
				413,
				json.object({ error = `a batch holds at most {telemetryConstants.MAX_APP_EVENTS} events` })
			)
		end

		local now = formatTimestamp()
		local events: { QueuedEvent } = {}

		for _, rawEvent in rawEvents do
			table.insert(events, parseTelemetryEvent(rawEvent, now))
		end

		local queued = queueTelemetryEvents(root, events, environment or process.env, build)

		return shared.reply(202, json.object({ queued = queued }))
	end)

	return if didSucceed then response :: Response else shared.reply(400, json.object({ error = tostring(response) }))
end

-- `POST` deletes the usage data this machine shared, from the Delete button in
-- the app's Settings. The reply is the status it leaves, with `deleted` saying
-- whether there was anything to delete. When the backend can't delete it, the
-- reply is a 502 with the reason, which the app shows.
function telemetry.handleDelete(
	request: net.ReceivedRequest,
	root: string,
	environment: { [string]: string }?,
	-- Specs pass this to stand in for the backend.
	requestAsync: typeof(requestTelemetryAsync)?
): Response
	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local resolvedEnvironment = environment or process.env
	local outcome, failure = deleteTelemetryDataAsync(root, {
		environment = resolvedEnvironment,
		requestTelemetryAsync = requestAsync,
	})

	if outcome == "failed" then
		return shared.reply(502, json.object({ error = failure }))
	end

	local status = serializeTelemetryStatus(getTelemetryStatus(root, resolvedEnvironment))
	status.deleted = outcome == "deleted"

	return shared.reply(200, status)
end

return table.freeze(telemetry)
