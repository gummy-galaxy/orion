local mcpTypes = require("@root/cli/mcp/types")
local workspaceField = require("@root/cli/mcp/tools/workspaceField")

type Tool = mcpTypes.Tool

local tool: Tool = {
	name = "orion_group",
	description = "Wrap existing items in a new group.",
	command = { "group" },
	json = true,
	fields = {
		{ name = "label", kind = "string", required = true, minLength = 1, at = "positional" },
		{ name = "items", kind = "strings", required = true, at = "csv", flag = "items" },
		workspaceField,
	},
}

return tool
