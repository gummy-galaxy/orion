local mcpTypes = require("@root/cli/mcp/types")

type Tool = mcpTypes.Tool

local tool: Tool = {
	name = "orion_create_workspace",
	description = "Create an Orion workspace.",
	command = { "workspace", "create" },
	fields = {
		{ name = "name", kind = "workspace", required = true, at = "positional" },
		{ name = "label", kind = "string", at = "option" },
		{ name = "owner", kind = "string", at = "option" },
	},
}

return tool
