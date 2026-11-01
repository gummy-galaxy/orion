local getBuild = require("@root/common/getBuild")
local getTelemetryQuietReason = require("@root/telemetry/getTelemetryQuietReason")
local getTelemetryStatus = require("@root/telemetry/getTelemetryStatus")
local types = require("@root/types")

type Build = types.Build

-- Whether events may be queued: the machine opted in, with no override, and
-- this isn't a dev build, perf run, or CI. Callers that do extra work to build
-- an event check this first, so a machine that isn't sharing pays nothing.
local function canQueueTelemetry(root: string, environment: { [string]: string }, build: Build?): boolean
	return getTelemetryStatus(root, environment).enabled
		and getTelemetryQuietReason(environment, build or getBuild()) == nil
end

return canQueueTelemetry
