--[[
	Checks the desktop shell: Rust formatting, Clippy, and a Tauri build without installers. Clippy compiles the shell,
	which needs the built canvas and the CLI sidecar in place, so those are built first.
]]
local FlipbookBatteries = require("@flipbook-batteries")
local path = require("@std/path")

local run = FlipbookBatteries.run

local root = path.resolve("..")
local app = path.join(root, "app")
local desktop = path.join(root, "desktop")
local shell = path.join(desktop, "src-tauri")

run("cargo", { "fmt", "--check" }, { cwd = shell })

run("npm", { "run", "build" }, { cwd = app })
run("sh", { "scripts/prepare-sidecar.sh" }, { cwd = desktop })

run("cargo", { "clippy", "--all-targets", "--", "-D", "warnings" }, { cwd = shell })
run("npx", { "tauri", "build", "--no-bundle" }, { cwd = desktop })
