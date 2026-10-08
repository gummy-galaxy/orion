local mcpTypes = require("@root/cli/mcp/types")
local workspaceField = require("@root/cli/mcp/tools/workspaceField")

type Tool = mcpTypes.Tool

local tool: Tool = {
	name = "orion_images",
	description = "List image nodes in an Orion workspace.",
	annotations = { readOnlyHint = true },
	command = { "media", "list" },
	json = true,
	fields = { workspaceField },
}

return tool
