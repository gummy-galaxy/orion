local mcpTypes = require("@root/cli/mcp/types")
local workspaceField = require("@root/cli/mcp/tools/workspaceField")

type Tool = mcpTypes.Tool

local tool: Tool = {
	name = "orion_link",
	description = "Connect two items, optionally as a related link that does not block work.",
	command = { "link" },
	fields = {
		{ name = "from", kind = "id", required = true, at = "positional" },
		{ name = "to", kind = "id", required = true, at = "positional" },
		workspaceField,
		{ name = "related", kind = "boolean", at = "flag", flag = "related" },
	},
}

return tool
