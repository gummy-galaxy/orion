local cli = require("@batteries/cli")

local aliasTypes = require("@root/aliases/types")
local cliTypes = require("@root/cli/types")
local describeCommands = require("@root/cli/describeCommands")
local types = require("@root/types")

export type Dependencies = {
	runner: types.CommandRunner?,
	write: ((string) -> ())?,
	-- Where notices go, such as an old command name being rewritten. Defaults
	-- to stderr.
	warn: ((string) -> ())?,
	-- The renamed commands and options to accept. Defaults to the shipped
	-- entries.
	aliases: { aliasTypes.Alias }?,
	dataDir: string?,
	workspace: string?,
	now: (() -> string)?,
	exit: ((code: number) -> ())?,
}

export type Context = {
	dir: string,
	root: string,
	workspace: string,
	-- The canvas named with --canvas, if any, before falling back to the
	-- selected one.
	requestedWorkspace: string?,
	write: (string) -> (),
	asJson: boolean,
	runner: types.CommandRunner,
	now: () -> string,
	-- Ends the process with a status, for commands such as canvas check that
	-- report findings through it.
	exit: (code: number) -> (),
	-- Runs another CLI command in this process, for commands such as mcp that
	-- relay to the CLI.
	execute: (argv: { string }, options: Dependencies?) -> (),
	-- Describes every command, for commands such as mcp that build on the
	-- command table.
	describe: () -> describeCommands.CommandDescription,
}

export type Command = {
	read help: string,
	read define: (cli.Parser) -> (),
	read run: (cli.Parser, Context) -> (),
	-- Every command with no subcommands declares its MCP tool, or why it has
	-- none.
	read mcp: cliTypes.ToolDeclaration?,
}

return nil
