local buildInfo = require("@root/buildInfo")
local types = require("@root/types")

type Build = types.Build

-- `lute run build` stamps each binary with the commit it was built from.
-- Running from source reports "dev" instead, and a binary built with
-- uncommitted changes has a commit ending in "-dirty". Both of those are dev
-- builds, and so is one built outside git, whose commit is "unknown", since
-- nobody can trace it to a release. Any other build counts as a release.
--
-- This describes the running build. Specs pass a `commit` to describe a build
-- stamped with that commit instead.
local function getBuild(commit: string?): Build
	local resolvedCommit = commit or buildInfo.commit
	local isDev = resolvedCommit == "dev" or resolvedCommit == "unknown" or resolvedCommit:sub(-6) == "-dirty"

	return {
		version = buildInfo.version,
		commit = resolvedCommit,
		channel = if isDev then "dev" else "release",
	}
end

return getBuild
