--[[
	Checks the desktop shell: Rust formatting, Clippy, and a Tauri build. Clippy compiles the shell, which needs the
	built canvas and the CLI sidecar in place, so those are built first. The build makes one installer for this
	platform: a disk image on macOS, an NSIS setup program on Windows, and a Debian package on Linux.
]]
local FlipbookBatteries = require("@flipbook-batteries")
local path = require("@std/path")
local system = require("@std/system")

local run = FlipbookBatteries.run

local root = path.resolve("..")
local app = path.join(root, "app")
local desktop = path.join(root, "desktop")
local shell = path.join(desktop, "src-tauri")
local cliDir = path.join(root, "cli")
local bundle = if system.macos then "dmg" elseif system.win32 then "nsis" else "deb"

run("cargo", { "fmt", "--check" }, { cwd = shell })

run("npm", { "run", "build" }, { cwd = app })
run("lute", { "run", "prepare-sidecar" }, { cwd = cliDir })

run("cargo", { "clippy", "--all-targets", "--", "-D", "warnings" }, { cwd = shell })
run("npx", { "tauri", "build", "--bundles", bundle }, { cwd = desktop })
