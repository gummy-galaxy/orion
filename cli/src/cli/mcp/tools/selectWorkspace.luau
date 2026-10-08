local mcpTypes = require("@root/cli/mcp/types")

type Tool = mcpTypes.Tool

local tool: Tool = {
	name = "orion_select_workspace",
	description = "Set the active Orion workspace shown by the app.",
	command = { "workspace", "use" },
	fields = {
		{ name = "name", kind = "workspace", required = true, at = "positional" },
	},
}

return tool
