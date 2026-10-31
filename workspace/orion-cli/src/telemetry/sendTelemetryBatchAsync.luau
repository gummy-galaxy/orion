local json = require("@std/json")
local net = require("@std/net")

local requestTelemetryAsync = require("@root/telemetry/requestTelemetryAsync")
local serializeTelemetryEvent = require("@root/telemetry/serializeTelemetryEvent")
local telemetryTypes = require("@root/telemetry/types")
local types = require("@root/types")

type Build = types.Build
type QueuedEvent = telemetryTypes.QueuedEvent

--[[
	Posts one batch to the backend and reports whether it was accepted, and why
	not when it wasn't. Nothing here retries: a batch that fails is the caller's
	to drop.
]]
local function sendTelemetryBatchAsync(
	endpoint: string,
	installId: string,
	build: Build,
	events: { QueuedEvent },
	timeoutSeconds: number
): (boolean, string?)
	local serialized = {}

	for _, event in events do
		table.insert(serialized, serializeTelemetryEvent(event))
	end

	local body = json.serialize(json.object({
		installId = installId,
		build = json.object({ version = build.version, commit = build.commit, channel = build.channel }),
		events = serialized,
	}))
	local metadata: net.Metadata = {
		method = "POST",
		headers = { ["Content-Type"] = "application/json" },
		body = body,
	}
	local response, failure = requestTelemetryAsync(endpoint, metadata, timeoutSeconds)

	if not response then
		return false, failure
	end

	if not response.ok then
		return false, `the backend answered {response.status}`
	end

	return true, nil
end

return sendTelemetryBatchAsync
