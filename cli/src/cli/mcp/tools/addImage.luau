local mcpTypes = require("@root/cli/mcp/types")
local workspaceField = require("@root/cli/mcp/tools/workspaceField")

type Tool = mcpTypes.Tool

local tool: Tool = {
	name = "orion_add_image",
	description = "Import a local PNG, JPEG, GIF, or WebP file as an image node. The CLI copies it into the workspace assets folder.",
	command = { "media", "insert" },
	json = true,
	fields = {
		{
			name = "path",
			kind = "string",
			required = true,
			minLength = 1,
			description = "Absolute path to a local image file.",
			at = "positional",
		},
		{ name = "label", kind = "string", minLength = 1, at = "option" },
		workspaceField,
		{ name = "group", kind = "id", at = "option" },
	},
}

return tool
