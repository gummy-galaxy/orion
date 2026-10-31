--[[
	Builds the CLI.

	lute run build
		Compiles the CLI into workspace/orion-cli/build/orion, stamped with the
		commit it comes from, and runs it once to check every package bundled.

	lute run build package
		Zips the binary `lute run build` wrote, such as
		`workspace/orion-cli/build/orion-linux-x86_64.zip`, in the form Rokit
		and Foreman install from a GitHub release. The name carries the OS and
		architecture they match on, and the binary is the zip's only entry,
		since Foreman extracts the first one. Zipping also keeps the executable
		bit, which artifact uploads drop.
]]
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local project = require("@repository/project")
local system = require("@std/system")

local run = require("@cli/run")
local runScript = require("@cli/runScript")

local BUILD_INFO_PATH = path.join(project.CLI_PATH, "src", "buildInfo.luau")
-- The commit buildInfo.luau is checked in with. Builds stamp their own commit
-- and then put this back.
local CHECKED_IN_COMMIT = "dev"

local binaryName = if system.win32 then "orion.exe" else "orion"
local platformName = if system.win32 then "windows" elseif system.macos then "macos" else "linux"

-- Reads the short commit this build comes from, marked "-dirty" when tracked
-- files differ from it. Falls back to "unknown" outside a git checkout.
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

local function build()
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

	-- Resets the file before anything else, so a build interrupted while
	-- stamping cannot leave its commit behind. The stamp is written and
	-- restored inside pcall, so a failed compile still puts the checked-in
	-- commit back.
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

	-- A binary missing a package still compiles but fails on its first require,
	-- so run it here to catch that before anything ships it.
	local smoke = process.run({ outputPath, "--help" })
	assert(
		smoke.ok,
		`{outputPath} failed to start: {smoke.stderr}; run lute run install so packages bundle from the checkout`
	)
end

local function packageBinary()
	local binaryPath = tostring(path.join(project.BUILD_PATH, binaryName))
	local archivePath = tostring(path.join(project.BUILD_PATH, `orion-{platformName}-{system.arch}.zip`))

	-- Windows runners have no `zip`, but their bsdtar writes a zip when the
	-- archive name ends in `.zip`.
	local command = if system.win32
		then { "tar", "-a", "-cf", archivePath, "-C", tostring(project.BUILD_PATH), binaryName }
		else { "zip", "-j", archivePath, binaryPath }

	local packed = process.run(command, { stdio = "inherit" })
	assert(packed.ok, `packaging failed ({packed.exitcode})`)

	print(`Packed {archivePath}`)
end

local STEPS: { [string]: () -> () } = {
	package = packageBinary,
}

runScript(function()
	local name = process.args[2]

	if name == nil then
		build()
		return
	end

	local step = STEPS[name]
	assert(step, `unknown build step {name}; try lute run build, or lute run build package`)
	step()
end)
