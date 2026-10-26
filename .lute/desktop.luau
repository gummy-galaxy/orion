--[[
	Checks the desktop shell: Rust formatting, Clippy, and a Tauri build. Clippy
	compiles the shell, which needs the built canvas and the CLI sidecar in
	place, so those are built first. The build makes one installer for this
	platform: a disk image on macOS, an NSIS setup program on Windows, and a
	Debian package on Linux.
]]
local project = require("@repository/project")
local system = require("@std/system")

local run = require("@cli/run")
local runScript = require("@cli/runScript")

local bundle = if system.macos then "dmg" elseif system.win32 then "nsis" else "deb"

runScript(function()
	run("cargo", { "fmt", "--check" }, { cwd = project.DESKTOP_PATH })

	run("npm", { "run", "build" }, { cwd = project.APP_PATH })
	run("lute", { "run", "prepare-sidecar" })

	run("cargo", { "clippy", "--all-targets", "--", "-D", "warnings" }, { cwd = project.DESKTOP_PATH })
	run("npx", { "tauri", "build", "--bundles", bundle }, { cwd = project.DESKTOP_PATH })
end)
