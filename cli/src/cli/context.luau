local cli = require("@batteries/cli")
local types = require("@root/types")

export type Dependencies = {
	runner: types.CommandRunner?,
	write: ((string) -> ())?,
	dataDir: string?,
	workspace: string?,
	now: (() -> string)?,
}

export type Context = {
	dir: string,
	root: string,
	workspace: string,
	-- The workspace named with --workspace, if any, before falling back to the selected one.
	requestedWorkspace: string?,
	write: (string) -> (),
	asJson: boolean,
	runner: types.CommandRunner,
	now: () -> string,
	-- Runs another CLI command in this process, for commands such as mcp that relay to the CLI.
	execute: (argv: { string }, options: Dependencies?) -> (),
}

export type Command = {
	read help: string,
	read define: (cli.Parser) -> (),
	read run: (cli.Parser, Context) -> (),
}

return nil
