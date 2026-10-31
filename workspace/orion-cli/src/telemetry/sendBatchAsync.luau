local json = require("@std/json")
local net = require("@std/net")
local task = require("@std/task")

local serializeQueuedEvent = require("@root/telemetry/serializeQueuedEvent")
local telemetryTypes = require("@root/telemetry/types")

type Build = telemetryTypes.Build
type QueuedEvent = telemetryTypes.QueuedEvent

local POLL_SECONDS = 0.1

--[[
	Posts one batch to the backend and reports whether it was accepted, and why
	not when it wasn't. A request that takes longer than `timeoutSeconds` is
	given up on and left to finish in the background, since the request itself
	has no timeout. Nothing here retries: a batch that fails is the caller's to
	drop.
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
	local isDone = false
	local isAccepted = false
	local failure: string?

	task.spawn(function()
		local didSend, response = pcall(net.request, endpoint, metadata)

		if not didSend then
			failure = tostring(response)
		elseif not response.ok then
			failure = `the backend answered {response.status}`
		end

		isAccepted = didSend and response.ok
		isDone = true
	end)

	local waited = 0

	while not isDone and waited < timeoutSeconds do
		task.wait(POLL_SECONDS)
		waited += POLL_SECONDS
	end

	if not isDone then
		return false, `no answer within {timeoutSeconds} seconds`
	end

	return isAccepted, failure
end

return sendBatchAsync
