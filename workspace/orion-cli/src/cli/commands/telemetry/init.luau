local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local delete = require("@root/cli/commands/telemetry/delete")
local off = require("@root/cli/commands/telemetry/off")
local on = require("@root/cli/commands/telemetry/on")
local runSubcommand = require("@root/cli/runSubcommand")
local status = require("@root/cli/commands/telemetry/status")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { status = status, on = on, off = off, delete = delete }

return table.freeze({
	help = "Choose whether this machine shares anonymous usage data",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "status", "on", "off", "delete" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
