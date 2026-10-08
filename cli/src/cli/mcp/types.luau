local json = require("@std/json")

local platformDirs = require("@root/platformDirs")
local types = require("@root/types")

export type FieldKind = "string" | "id" | "workspace" | "enum" | "boolean" | "strings" | "int"
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

export type ClientRequest = {
	binary: string,
	home: string,
	clients: { string },
	write: (string) -> (),
	runner: types.CommandRunner,
	environment: { [string]: string },
	platform: platformDirs.Platform,
}

return nil
