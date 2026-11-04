--[[
	Builds and checks the desktop shell.

	lute run desktop
		Checks the shell: Rust formatting, Clippy, and a Tauri build. Clippy
		compiles the shell, which needs the built canvas and the CLI sidecar in
		place, so those are built first. The build makes one installer for this
		platform: a disk image on macOS, an NSIS setup program on Windows, and a
		Debian package on Linux.

	lute run desktop sidecar
		Builds the CLI and copies it into workspace/orion-desktop/binaries under
		the name Tauri bundles it by, which carries this machine's Rust target.

	lute run desktop acknowledgements
		Writes the licenses page the app opens from Help › Acknowledgements.
		Run it after the canvas build.

	Tauri's own build runs the sidecar and acknowledgements steps before it
	bundles.
]]
local process = require("@std/process")
local system = require("@std/system")

local prepareSidecar = require("@self/sidecar")
local project = require("@repository/project")
local run = require("@workspace/orion-cli/src/common/process/run")
local runScript = require("@workspace/orion-cli/src/common/process/runScript")
local writeAcknowledgements = require("@self/acknowledgements")

local bundle = if system.macos then "dmg" elseif system.win32 then "nsis" else "deb"

local function check()
	run("cargo", { "fmt", "--check" }, { cwd = project.DESKTOP_PATH })

	run("npm", { "run", "build" }, { cwd = project.APP_PATH })
	prepareSidecar()

	run("cargo", { "clippy", "--all-targets", "--", "-D", "warnings" }, { cwd = project.DESKTOP_PATH })
	run("npx", { "tauri", "build", "--bundles", bundle }, { cwd = project.DESKTOP_PATH })
end

local STEPS: { [string]: () -> () } = {
	sidecar = prepareSidecar,
	acknowledgements = writeAcknowledgements,
}

runScript(function()
	local name = process.args[2]

	if name == nil then
		check()
		return
	end

	local step = STEPS[name]
	assert(step, `unknown desktop step {name}; try sidecar or acknowledgements`)
	step()
end)
