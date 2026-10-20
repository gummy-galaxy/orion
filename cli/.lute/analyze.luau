local run = require("@root/run")
local runScript = require("@root/runScript")

local sources =
	{ "src", "cli.luau", ".lute", "project.luau", "loom.config.luau", ".config.luau", "../.lute", "../.config.luau" }

runScript(function()
	run("stylua", { "--check", table.unpack(sources) })
	-- Linting in parallel crashes lute v1.0.1-nightly.20260924 on Linux: its worker VMs race on thread references,
	-- so it segfaults or prints "Cannot resume a non-thread reference". Sequential linting avoids the workers.
	run("lute", { "lint", "--sequential", table.unpack(sources) })
	run("lute", { "check", table.unpack(sources) })
end)
