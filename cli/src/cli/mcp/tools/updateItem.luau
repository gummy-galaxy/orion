local fieldValues = require("@root/fieldValues")
local mcpTypes = require("@root/cli/mcp/types")
local workspaceField = require("@root/cli/mcp/tools/workspaceField")

type Tool = mcpTypes.Tool

local WHO = table.clone(fieldValues.who)
table.insert(WHO, "")

local tool: Tool = {
	name = "orion_update_item",
	description = "Change fields on an existing Orion item or group.",
	command = { "set" },
	json = true,
	fields = {
		{ name = "id", kind = "id", required = true, at = "positional" },
		workspaceField,
		{ name = "label", kind = "string", at = "option" },
		{ name = "status", kind = "enum", values = fieldValues.statuses, at = "option" },
		{
			name = "who",
			kind = "enum",
			values = WHO,
			description = "Whose move: you, review, or ci. Empty clears it.",
			at = "option",
		},
		{ name = "note", kind = "string", at = "option" },
		{ name = "repo", kind = "string", at = "option" },
		{ name = "pr", kind = "int", at = "option" },
	},
}

return tool
