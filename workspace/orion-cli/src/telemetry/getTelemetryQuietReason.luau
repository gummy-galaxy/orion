local types = require("@root/types")

type Build = types.Build

-- Some runs of Orion aren't people using it: dev builds, perf runs
-- (`ORION_PERF=1`), and CI. Their events would only muddy the usage charts, so
-- these runs never queue or send anything, even when telemetry is on. This
-- returns why a run is one of them, or nil when it may send.
local function getTelemetryQuietReason(environment: { [string]: string }, build: Build): string?
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

return getTelemetryQuietReason
