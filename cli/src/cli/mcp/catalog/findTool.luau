local mcpTypes = require("@root/cli/mcp/types")

type Tool = mcpTypes.Tool

local function findTool(tools: { Tool }, name: string): Tool?
	for _, tool in tools do
		if tool.name == name then
			return tool
		end
	end

	return nil
end

return findTool
