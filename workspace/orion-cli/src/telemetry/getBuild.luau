local buildInfo = require("@root/buildInfo")
local telemetryTypes = require("@root/telemetry/types")

type Build = telemetryTypes.Build

-- The build that events are sent from. A checkout reports its commit as "dev"
-- and a build with uncommitted changes ends in "-dirty", and neither is a
-- release anyone installed, so both are dev builds.
local function getBuild(commit: string?): Build
	local resolvedCommit = commit or buildInfo.commit
	local isDev = resolvedCommit == "dev" or resolvedCommit:sub(-6) == "-dirty"

	return {
		version = buildInfo.version,
		commit = resolvedCommit,
		channel = if isDev then "dev" else "release",
	}
end

return getBuild
