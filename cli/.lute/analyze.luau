local FlipbookBatteries = require("@flipbook-batteries")

local run = FlipbookBatteries.run

local sources = { "src", "cli.luau", ".lute", "project.luau", "loom.config.luau", ".config.luau" }

run("stylua", { "--check", table.unpack(sources) })
run("lute", { "lint", table.unpack(sources) })
run("lute", { "check", table.unpack(sources) })
