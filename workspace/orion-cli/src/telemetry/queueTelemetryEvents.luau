local appendTelemetryQueue = require("@root/telemetry/appendTelemetryQueue")
local getBuild = require("@root/common/getBuild")
local getTelemetryQuietReason = require("@root/telemetry/getTelemetryQuietReason")
local getTelemetryStatus = require("@root/telemetry/getTelemetryStatus")
local telemetryTypes = require("@root/telemetry/types")
local types = require("@root/types")

type Build = types.Build
type QueuedEvent = telemetryTypes.QueuedEvent

-- Adds events to the queue for `orion server start` to send. Events are only
-- queued when this machine opted in and nothing overrides that, such as
-- `DO_NOT_TRACK`, and when the run isn't a dev build, a perf run, or CI.
-- Otherwise they're dropped here, so nothing is kept to send later. Returns
-- how many events were queued.
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
