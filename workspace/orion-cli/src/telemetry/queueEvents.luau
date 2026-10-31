local appendQueue = require("@root/telemetry/appendQueue")
local getBuild = require("@root/telemetry/getBuild")
local getQuietReason = require("@root/telemetry/getQuietReason")
local getStatus = require("@root/telemetry/getStatus")
local telemetryTypes = require("@root/telemetry/types")

type Build = telemetryTypes.Build
type QueuedEvent = telemetryTypes.QueuedEvent

-- Queues events for `orion server start` to send, but only on a machine that
-- opted in, with no override, outside dev builds, perf runs, and CI. Anything
-- else is dropped here, so nothing is kept to send later. Returns how many
-- were queued.
local function queueEvents(
	root: string,
	events: { QueuedEvent },
	environment: { [string]: string },
	build: Build?
): number
	if not getStatus(root, environment).enabled or getQuietReason(environment, build or getBuild()) then
		return 0
	end

	return appendQueue(root, events)
end

return queueEvents
