local json = require("@std/json")
local net = require("@std/net")

local requestAsync = require("@root/telemetry/requestAsync")
local serializeQueuedEvent = require("@root/telemetry/serializeQueuedEvent")
local telemetryTypes = require("@root/telemetry/types")

type Build = telemetryTypes.Build
type QueuedEvent = telemetryTypes.QueuedEvent

--[[
	Posts one batch to the backend and reports whether it was accepted, and why
	not when it wasn't. Nothing here retries: a batch that fails is the caller's
	to drop.
]]
local function sendBatchAsync(
	endpoint: string,
	installId: string,
	build: Build,
	events: { QueuedEvent },
	timeoutSeconds: number
): (boolean, string?)
	local serialized = {}

	for _, event in events do
		table.insert(serialized, serializeQueuedEvent(event))
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
	local response, failure = requestAsync(endpoint, metadata, timeoutSeconds)

	if not response then
		return false, failure
	end

	if not response.ok then
		return false, `the backend answered {response.status}`
	end

	return true, nil
end

return sendBatchAsync
