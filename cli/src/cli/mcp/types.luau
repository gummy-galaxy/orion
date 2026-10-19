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

-- A tool runs one CLI command, named after its path, such as orion_card_add for orion card add.
export type Tool = {
	name: string,
	description: string,
	command: { string },
	fields: { Field },
	-- Whether calls add --json, which every command that takes it does.
	json: boolean,
	annotations: cliTypes.Annotations?,
}

export type Run = (argv: { string }, write: (string) -> ()) -> ()

return nil
