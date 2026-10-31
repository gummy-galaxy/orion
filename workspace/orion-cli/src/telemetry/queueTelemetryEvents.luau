local appendTelemetryQueue = require("@root/telemetry/appendTelemetryQueue")
local getBuild = require("@root/getBuild")
local getTelemetryQuietReason = require("@root/telemetry/getTelemetryQuietReason")
local getTelemetryStatus = require("@root/telemetry/getTelemetryStatus")
local telemetryTypes = require("@root/telemetry/types")
local types = require("@root/types")

type Build = types.Build
type QueuedEvent = telemetryTypes.QueuedEvent

-- Queues events for `orion server start` to send, but only on a machine that
-- opted in, with no override, outside dev builds, perf runs, and CI. Anything
-- else is dropped here, so nothing is kept to send later. Returns how many
-- were queued.
local function queueTelemetryEvents(
	root: string,
	events: { QueuedEvent },
	environment: { [string]: string },
	build: Build?
): number
	if
		not getTelemetryStatus(root, environment).enabled or getTelemetryQuietReason(environment, build or getBuild())
	then
		return 0
	end

	return appendTelemetryQueue(root, events)
end

return queueTelemetryEvents
