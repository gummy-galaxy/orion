local mcpTypes = require("@root/cli/mcp/types")
local tools = require("@root/cli/mcp/tools")

type Tool = mcpTypes.Tool

local function findTool(name: string): Tool?
	for _, tool in tools do
		if tool.name == name then
			return tool
		end
	end

	return nil
end

return findTool
