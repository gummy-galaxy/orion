local mcpTypes = require("@root/cli/mcp/types")
local workspaceField = require("@root/cli/mcp/tools/workspaceField")

type Tool = mcpTypes.Tool

local tool: Tool = {
	name = "orion_remove",
	description = "Delete an item or group from the canvas.",
	annotations = { destructiveHint = true },
	command = { "remove" },
	fields = {
		{ name = "id", kind = "id", required = true, at = "positional" },
		workspaceField,
	},
}

return tool
