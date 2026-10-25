--[[
	Zips the built CLI for this platform, such as `workspace/orion-cli/build/orion-linux-x86_64.zip`, in the form Rokit and Foreman install
	from a GitHub release. The name carries the OS and architecture they match on, and the binary is the zip's only
	entry, since Foreman extracts the first one. Zipping also keeps the executable bit, which artifact uploads drop.
]]
local path = require("@std/path")
local process = require("@std/process")
local project = require("@repository/project")
local system = require("@std/system")

local runScript = require("@cli/runScript")

local binaryName = if system.win32 then "orion.exe" else "orion"
local platformName = if system.win32 then "windows" elseif system.macos then "macos" else "linux"
local binaryPath = tostring(path.join(project.BUILD_PATH, binaryName))
local archivePath = tostring(path.join(project.BUILD_PATH, `orion-{platformName}-{system.arch}.zip`))

-- Windows runners have no `zip`, but their bsdtar writes a zip when the archive name ends in `.zip`.
local command = if system.win32
	then { "tar", "-a", "-cf", archivePath, "-C", tostring(project.BUILD_PATH), binaryName }
	else { "zip", "-j", archivePath, binaryPath }

runScript(function()
	local packed = process.run(command, { stdio = "inherit" })
	assert(packed.ok, `packaging failed ({packed.exitcode})`)

	print(`Packed {archivePath}`)
end)
