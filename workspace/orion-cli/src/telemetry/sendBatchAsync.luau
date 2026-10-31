local json = require("@std/json")
local net = require("@std/net")
local task = require("@std/task")

local serializeQueuedEvent = require("@root/telemetry/serializeQueuedEvent")
local telemetryTypes = require("@root/telemetry/types")

type Build = telemetryTypes.Build
type QueuedEvent = telemetryTypes.QueuedEvent

local POLL_SECONDS = 0.1

--[[
	Posts one batch to the backend and reports whether it was accepted. A
	request that takes longer than `timeoutSeconds` is given up on and left to
	finish in the background, since the request itself has no timeout. Nothing
	here retries: a batch that fails is the caller's to drop.
]]
local function sendBatchAsync(
	endpoint: string,
	installId: string,
	build: Build,
	events: { QueuedEvent },
	timeoutSeconds: number
): boolean
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

	task.spawn(function()
		local didSend, response = pcall(net.request, endpoint, metadata)
		isAccepted = didSend and response.ok
		isDone = true
	end)

	local waited = 0

	while not isDone and waited < timeoutSeconds do
		task.wait(POLL_SECONDS)
		waited += POLL_SECONDS
	end

	return isDone and isAccepted
end

return sendBatchAsync
