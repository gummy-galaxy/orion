--[[
	Checks the desktop shell: Rust formatting, Clippy, and a Tauri build. Clippy compiles the shell, which needs the
	built canvas and the CLI sidecar in place, so those are built first. The build makes one installer for this
	platform: a disk image on macOS, an NSIS setup program on Windows, and a Debian package on Linux.
]]
local path = require("@std/path")
local system = require("@std/system")

local run = require("@root/run")
local runScript = require("@root/runScript")

local workspaceDir = path.resolve("..")
local app = path.join(workspaceDir, "orion-app")
local desktop = path.join(workspaceDir, "orion-desktop")
local cliDir = path.join(workspaceDir, "orion-cli")
local bundle = if system.macos then "dmg" elseif system.win32 then "nsis" else "deb"

runScript(function()
	run("cargo", { "fmt", "--check" }, { cwd = desktop })

	run("npm", { "run", "build" }, { cwd = app })
	run("lute", { "run", "prepare-sidecar" }, { cwd = cliDir })

	run("cargo", { "clippy", "--all-targets", "--", "-D", "warnings" }, { cwd = desktop })
	run("npx", { "tauri", "build", "--bundles", bundle }, { cwd = desktop })
end)
