local json = require("@std/json")
local path = require("@std/path")

local platformTypes = require("@root/platform/types")
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
	binary: path.Path,
	home: path.Path,
	clients: { string },
	write: (string) -> (),
	runner: types.CommandRunner,
	environment: { [string]: string },
	platform: platformTypes.Platform,
}

return nil
