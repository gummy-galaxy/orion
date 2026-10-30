local project = require("@repository/project")

local run = require("@cli/run")
local runScript = require("@cli/runScript")

-- The tools run from the CLI's folder, where stylua.toml and the lint rules'
-- config live.
local sources = {
	"src",
	"cli.luau",
	"loom.config.luau",
	".config.luau",
	"../../.lute",
	"../../project.luau",
	"../../.config.luau",
}

runScript(function()
	run("stylua", { "--check", table.unpack(sources) }, { cwd = project.CLI_PATH })
	-- Linting in parallel crashes lute v1.0.1-nightly.20260924 on Linux: its
	-- worker VMs race on thread references, so it segfaults or prints "Cannot
	-- resume a non-thread reference". Sequential linting avoids the workers.
	run("lute", { "lint", "--sequential", table.unpack(sources) }, { cwd = project.CLI_PATH })
	run("lute", { "check", table.unpack(sources) }, { cwd = project.CLI_PATH })
	-- The docs generator formats with the docs site's Prettier, so this needs
	-- `npm ci` in docs/ first.
	run("lute", { "run", "generate", "--check" })
end)
