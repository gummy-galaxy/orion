local json = require("@std/json")

local buildArgv = require("@root/cli/mcp/catalog/buildArgv")
local checkArguments = require("@root/cli/mcp/catalog/checkArguments")
local findTool = require("@root/cli/mcp/catalog/findTool")

-- Turns a tool call into the CLI arguments for the command it delegates to.
local function getToolArgv(name: string, arguments: json.Object): { string }
	local tool = assert(findTool(name), `unknown tool: {name}`)
	checkArguments(tool, arguments)

	if tool.build then
		return tool.build(arguments)
	end

	return buildArgv(tool, arguments)
end

return getToolArgv
