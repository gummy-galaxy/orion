local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local project = require("@repository/project")
local system = require("@std/system")

local run = require("@cli/run")
local runScript = require("@cli/runScript")

local BUILD_INFO_PATH = path.join(project.CLI_PATH, "src", "buildInfo.luau")
-- The commit buildInfo.luau is checked in with. Builds stamp their own commit and then put this back.
local CHECKED_IN_COMMIT = "dev"

-- Reads the short commit this build comes from, marked "-dirty" when tracked files differ from it.
-- Falls back to "unknown" outside a git checkout.
local function getCommit(): string
	local head = process.run({ "git", "rev-parse", "--short", "HEAD" })

	if not head.ok then
		return "unknown"
	end

	local commit = string.gsub(head.stdout, "%s+$", "")
	local status = process.run({ "git", "status", "--porcelain", "--untracked-files=no" })

	if status.ok and string.find(status.stdout, "%S") then
		return `{commit}-dirty`
	end

	return commit
end

local function setCommit(source: string, commit: string): string
	return (string.gsub(source, 'commit = "[^"]*"', `commit = "{commit}"`, 1))
end

runScript(function()
	local outputPath = tostring(project.BUILD_OUTPUT)
	local windowsOutputPath = outputPath .. ".exe"

	for _, stalePath in { outputPath, windowsOutputPath } do
		if fs.exists(stalePath) then
			fs.remove(stalePath)
		end
	end

	if system.os:lower() == "windows_nt" then
		outputPath = windowsOutputPath
	end

	if not fs.exists(project.BUILD_PATH) then
		fs.createDirectory(project.BUILD_PATH, { makeParents = true })
	end

	-- Resets the file before anything else, so a build interrupted while stamping cannot leave its commit behind.
	-- The stamp is written and restored inside pcall, so a failed compile still puts the checked-in commit back.
	local checkedIn = setCommit(fs.readFileToString(BUILD_INFO_PATH), CHECKED_IN_COMMIT)
	fs.writeStringToFile(BUILD_INFO_PATH, checkedIn)

	local compiled, compileError = pcall(function()
		fs.writeStringToFile(BUILD_INFO_PATH, setCommit(checkedIn, getCommit()))

		run("lute", {
			"compile",
			"cli.luau",
			"--output",
			outputPath,
			"--bundle-stats",
			"--show-require-graph",
		}, { cwd = project.CLI_PATH })
	end)

	fs.writeStringToFile(BUILD_INFO_PATH, checkedIn)

	if not compiled then
		error(compileError, 0)
	end

	assert(fs.exists(outputPath) and fs.type(outputPath) == "file", `native build did not produce {outputPath}`)

	-- Lute bundles ~/.loom/store only from a checkout under the home directory. Anywhere else the compile still
	-- succeeds, but the binary fails on its first require, so run it here to catch that before anything ships it.
	local smoke = process.run({ outputPath, "--help" })
	assert(
		smoke.ok,
		`{outputPath} failed to start: {smoke.stderr}; Lute only bundles ~/.loom/store from a checkout under the home directory`
	)
end)
