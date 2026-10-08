local mcpTypes = require("@root/cli/mcp/types")

type Field = mcpTypes.Field

local workspaceField: Field = {
	name = "workspace",
	kind = "workspace",
	description = "Workspace name. Omit to use the workspace selected in Orion.",
	at = "option",
	flag = "workspace",
}

return workspaceField
