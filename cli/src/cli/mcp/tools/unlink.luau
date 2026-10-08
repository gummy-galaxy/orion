local mcpTypes = require("@root/cli/mcp/types")
local workspaceField = require("@root/cli/mcp/tools/workspaceField")

type Tool = mcpTypes.Tool

local tool: Tool = {
	name = "orion_unlink",
	description = "Remove a dependency or related link between two items.",
	command = { "unlink" },
	fields = {
		{ name = "from", kind = "id", required = true, at = "positional" },
		{ name = "to", kind = "id", required = true, at = "positional" },
		workspaceField,
	},
}

return tool
