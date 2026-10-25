local fs = require("@std/fs")
local path = require("@std/path")
local project = require("@repository/project")
local system = require("@std/system")

local run = require("@cli/run")
local runScript = require("@cli/runScript")

local binariesPath = path.join(project.DESKTOP_PATH, "binaries")

runScript(function()
	local rustcVersion = assert(run("rustc", { "-vV" }, { captureOutput = true }), "rustc did not print its version")
	local triple = string.match(rustcVersion, "host: (%S+)")
	assert(triple, "Could not determine the Rust host target triple")

	run("lute", { "run", "build" })

	local extension = if system.win32 then ".exe" else ""
	local builtPath = tostring(project.BUILD_OUTPUT) .. extension
	assert(fs.exists(builtPath) and fs.type(builtPath) == "file", `build did not produce {builtPath}`)

	if not fs.exists(binariesPath) then
		fs.createDirectory(binariesPath, { makeParents = true })
	end

	fs.copy(builtPath, path.join(binariesPath, `orion-{triple}{extension}`))
end)
