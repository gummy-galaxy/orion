local cli = require("@batteries/cli")

local context = require("@root/cli/context")
local defineSubcommands = require("@root/cli/defineSubcommands")
local off = require("@root/cli/telemetry/off")
local on = require("@root/cli/telemetry/on")
local runSubcommand = require("@root/cli/runSubcommand")
local status = require("@root/cli/telemetry/status")

type Context = context.Context
type Command = context.Command

local COMMANDS: { [string]: Command } = { status = status, on = on, off = off }

return table.freeze({
	help = "Choose whether this machine shares anonymous usage data",
	define = function(parser: cli.Parser)
		defineSubcommands(parser, COMMANDS, { "status", "on", "off" })
	end,

	run = function(parser: cli.Parser, options: Context)
		runSubcommand(parser, COMMANDS, options)
	end,
})
