local mcpTypes = require("@root/cli/mcp/types")
local workspaceField = require("@root/cli/mcp/tools/workspaceField")

type Tool = mcpTypes.Tool

local tool: Tool = {
	name = "orion_add_note",
	description = "Add a canvas note, optionally inside a group or a dependency link.",
	command = { "note" },
	json = true,
	fields = {
		{ name = "text", kind = "string", required = true, minLength = 1, at = "positional" },
		workspaceField,
		{ name = "group", kind = "id", at = "option" },
		{ name = "after", kind = "id", at = "option" },
		{ name = "before", kind = "id", at = "option" },
	},
}

return tool
