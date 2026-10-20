local mcpTypes = require("@root/cli/mcp/types")

type Tool = mcpTypes.Tool

-- Finds a tool by its name, or by an old name from before a rename.
local function findTool(tools: { Tool }, name: string): Tool?
	for _, tool in tools do
		if tool.name == name or table.find(tool.aliases, name) then
			return tool
		end
	end

	return nil
end

return findTool
