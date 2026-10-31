local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local presets = require("@root/cli/commands/session/presets")
local runSubcommand = require("@root/cli/runSubcommand")
local start = require("@root/cli/commands/session/start")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = {
	presets = presets,
	start = start,
}

return table.freeze({
	help = "Agent sessions started from cards",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "start", "presets" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
