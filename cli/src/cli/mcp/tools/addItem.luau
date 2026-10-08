local fieldValues = require("@root/fieldValues")
local mcpTypes = require("@root/cli/mcp/types")
local workspaceField = require("@root/cli/mcp/tools/workspaceField")

type Tool = mcpTypes.Tool

local tool: Tool = {
	name = "orion_add_item",
	description = "Add a work item to the canvas.",
	command = { "add" },
	json = true,
	fields = {
		{ name = "title", kind = "string", required = true, minLength = 1, at = "positional" },
		workspaceField,
		{ name = "group", kind = "id", at = "option" },
		{ name = "repo", kind = "string", at = "option" },
		{ name = "pr", kind = "int", at = "option" },
		{ name = "status", kind = "enum", values = fieldValues.statuses, at = "option" },
	},
}

return tool
