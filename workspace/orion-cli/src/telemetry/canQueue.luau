local getBuild = require("@root/telemetry/getBuild")
local getQuietReason = require("@root/telemetry/getQuietReason")
local getStatus = require("@root/telemetry/getStatus")
local telemetryTypes = require("@root/telemetry/types")

type Build = telemetryTypes.Build

-- Whether events may be queued: the machine opted in, with no override, and
-- this isn't a dev build, perf run, or CI. Callers that do extra work to build
-- an event check this first, so a machine that isn't sharing pays nothing.
local function canQueue(root: string, environment: { [string]: string }, build: Build?): boolean
	return getStatus(root, environment).enabled and getQuietReason(environment, build or getBuild()) == nil
end

return canQueue
