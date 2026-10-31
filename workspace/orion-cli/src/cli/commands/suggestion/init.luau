local cli = require("@batteries/cli")

local apply = require("@root/cli/commands/suggestion/apply")
local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local dismiss = require("@root/cli/commands/suggestion/dismiss")
local find = require("@root/cli/commands/suggestion/find")
local list = require("@root/cli/commands/suggestion/list")
local runSubcommand = require("@root/cli/runSubcommand")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { find = find, list = list, apply = apply, dismiss = dismiss }

return table.freeze({
	help = "Suggested groups for related cards",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "find", "list", "apply", "dismiss" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
