local json = require("@std/json")

export type FieldKind = "string" | "id" | "canvas" | "enum" | "boolean" | "strings" | "int" | "operations"
export type Placement = "positional" | "option" | "flag" | "csv"

export type Field = {
	name: string,
	kind: FieldKind,
	at: Placement,
	flag: string?,
	required: boolean?,
	description: string?,
	values: { string }?,
	minLength: number?,
	-- The smallest value an int field takes. Defaults to 1.
	minimum: number?,
}

-- A tool maps its arguments onto an existing CLI command. Tools that need more than
-- the generic field mapping supply their own build.
export type Tool = {
	name: string,
	description: string,
	command: { string },
	fields: { Field },
	json: boolean?,
	annotations: { [string]: boolean }?,
	build: ((json.Object) -> { string })?,
}

export type Run = (argv: { string }, write: (string) -> ()) -> ()

return nil
