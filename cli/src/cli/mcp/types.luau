local json = require("@std/json")

export type FieldKind = "string" | "id" | "canvas" | "enum" | "boolean" | "strings" | "int" | "operations"

-- positional: one value before the options. variadic: a list of values after the positionals.
-- option and flag: named, and csv: a list joined with commas behind a named option.
export type Placement = "positional" | "variadic" | "option" | "flag" | "csv"

export type Field = {
	name: string,
	kind: FieldKind,
	at: Placement,
	-- The CLI argument this field maps to, when it isn't the field's own name.
	flag: string?,
	required: boolean?,
	description: string?,
	values: { string }?,
	minLength: number?,
	-- The smallest value an int field takes. Defaults to 1.
	minimum: number?,
}

-- A tool maps its arguments onto an existing CLI command. Tools that pick between commands list
-- them in commands, and tools that need more than the generic field mapping supply their own build.
export type Tool = {
	name: string,
	description: string,
	command: { string },
	commands: { { string } }?,
	fields: { Field },
	json: boolean?,
	annotations: { [string]: boolean }?,
	build: ((json.Object) -> { string })?,
}

export type Run = (argv: { string }, write: (string) -> ()) -> ()

return nil
