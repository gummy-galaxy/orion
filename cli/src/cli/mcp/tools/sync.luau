local mcpTypes = require("@root/cli/mcp/types")
local workspaceField = require("@root/cli/mcp/tools/workspaceField")

type Tool = mcpTypes.Tool

local tool: Tool = {
	name = "orion_sync",
	description = "Refresh pull request cards from GitHub. Discovery adds open authored PRs to Inbox when requested.",
	annotations = { openWorldHint = true },
	command = { "sync" },
	json = true,
	fields = {
		workspaceField,
		{ name = "dryRun", kind = "boolean", at = "flag", flag = "dry-run" },
		{ name = "discover", kind = "boolean", at = "flag", flag = "discover" },
	},
}

return tool
