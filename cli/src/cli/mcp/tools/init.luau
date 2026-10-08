local addImage = require("@root/cli/mcp/tools/addImage")
local addItem = require("@root/cli/mcp/tools/addItem")
local addNote = require("@root/cli/mcp/tools/addNote")
local createWorkspace = require("@root/cli/mcp/tools/createWorkspace")
local group = require("@root/cli/mcp/tools/group")
local images = require("@root/cli/mcp/tools/images")
local inspect = require("@root/cli/mcp/tools/inspect")
local link = require("@root/cli/mcp/tools/link")
local mcpTypes = require("@root/cli/mcp/types")
local move = require("@root/cli/mcp/tools/move")
local remove = require("@root/cli/mcp/tools/remove")
local selectWorkspace = require("@root/cli/mcp/tools/selectWorkspace")
local sync = require("@root/cli/mcp/tools/sync")
local unlink = require("@root/cli/mcp/tools/unlink")
local updateItem = require("@root/cli/mcp/tools/updateItem")
local workspaces = require("@root/cli/mcp/tools/workspaces")

type Tool = mcpTypes.Tool

-- Every tool the MCP server offers, in the order tools/list reports them. Add a tool
-- by giving it a module in this folder and listing it here.
local tools: { Tool } = {
	workspaces,
	inspect,
	addItem,
	updateItem,
	addNote,
	images,
	addImage,
	link,
	unlink,
	group,
	move,
	remove,
	createWorkspace,
	selectWorkspace,
	sync,
}

return table.freeze(tools)
