-- What an argument's value is, beyond the kind the parser knows. Flags are booleans. text is any string, id an
-- item or group id or selector, canvas a canvas name, enum one of a list of values, and integer a whole number.
-- A variadic is a list of separate values, or words joined into one text such as a label. A commaList is one
-- option holding values joined with commas, a jsonList is a JSON list of objects passed as its text, and a command
-- is a program and its arguments, as a JSON list of strings passed as its text.
export type ValueType =
	"boolean"
	| "text"
	| "id"
	| "canvas"
	| "enum"
	| "integer"
	| "words"
	| "list"
	| "commaList"
	| "jsonList"
	| "command"

-- How an argument reads to agents, when that differs from the CLI.
export type ArgumentMcp = {
	-- Agent-facing help for the tool's field, when the CLI's help isn't enough. Keep it rare.
	description: string?,
	-- Whether a tool call must give a value the parser lets the CLI leave out. Positionals and words always must.
	required: boolean?,
}

export type ArgumentDetails = {
	type: ValueType,
	-- The values an enum takes, with "" when an empty value clears the field.
	values: { string }?,
	-- The smallest value an integer takes. Defaults to 1.
	minimum: number?,
	mcp: ArgumentMcp?,
}

-- MCP's hints about what a tool does to the data, named as the protocol names them.
export type Annotations = {
	read readOnlyHint: boolean?,
	read destructiveHint: boolean?,
	read openWorldHint: boolean?,
}

-- An option a tool leaves out, with the reason.
export type Omission = {
	option: string,
	reason: string,
}

-- How a command appears as an MCP tool. Every command with no subcommands declares one, so a new command can't
-- leave MCP behind. The tool is named after the command's path, takes a field for each of its options, and adds
-- --json when the command takes it.
export type ToolDeclaration = {
	-- Agent-facing text for the tool, when the command's help isn't enough. Keep it rare.
	read description: string?,
	read annotations: Annotations?,
	-- Options the tool leaves out. canvas names the shared --canvas option.
	read omit: { Omission }?,
	-- Why MCP leaves the command out, along with any commands under it. A command that sets it has no tool.
	read skip: string?,
}

return nil
