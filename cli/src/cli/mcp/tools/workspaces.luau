local mcpTypes = require("@root/cli/mcp/types")

type Tool = mcpTypes.Tool

local tool: Tool = {
	name = "orion_workspaces",
	description = "List Orion workspaces and the active workspace.",
	annotations = { readOnlyHint = true },
	command = { "workspace", "list" },
	json = true,
	fields = {},
}

return tool
