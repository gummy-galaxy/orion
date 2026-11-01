local cliTypes = require("@root/cli/types")

-- One of a tool's arguments, built from a CLI option, positional, or variadic.
export type Field = {
	-- The CLI argument's name in camelCase, such as dryRun for --dry-run.
	name: string,
	-- The CLI argument it fills.
	argument: string,
	at: "positional" | "variadic" | "option" | "flag",
	type: cliTypes.ValueType,
	required: boolean,
	description: string?,
	values: { string }?,
	minimum: number?,
}

-- A tool runs one CLI command, named after its path, such as orion_card_create
-- for orion card create.
export type Tool = {
	name: string,
	description: string,
	command: { string },
	fields: { Field },
	-- Whether calls add --json, which every command that takes it does.
	json: boolean,
	annotations: cliTypes.Annotations?,
	-- Old names a call may still use after a rename, which tools/list doesn't
	-- show.
	aliases: { string },
	-- Old argument names after an option rename, each with the field it now
	-- fills.
	renamedArguments: { [string]: string },
}

export type Run = (argv: { string }, write: (string) -> ()) -> ()

-- Lets the server report what it serves, for usage telemetry.
export type Hooks = {
	-- A client connected, giving the name it introduced itself with, if any.
	onConnected: ((clientName: string?) -> ())?,
	-- A tool call finished, under the tool's current name.
	onToolCalled: ((name: string, durationMs: number, failed: boolean) -> ())?,
}

return nil
