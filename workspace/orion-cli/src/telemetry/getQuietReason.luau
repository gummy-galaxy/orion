local telemetryTypes = require("@root/telemetry/types")

type Build = telemetryTypes.Build

-- Why this run never queues or sends usage events, whatever was chosen, or nil
-- when it may. Dev builds, perf runs, and CI aren't people using Orion, so
-- their events would only muddy the charts.
local function getQuietReason(environment: { [string]: string }, build: Build): string?
	if build.channel == "dev" then
		return "a dev build"
	end

	if environment.ORION_PERF == "1" then
		return "ORION_PERF"
	end

	local ci = environment.CI

	if ci and ci ~= "" and ci ~= "0" and ci:lower() ~= "false" then
		return "CI"
	end

	return nil
end

return getQuietReason
