local json = require("@std/json")

local cleanErrorMessage = require("@root/cli/mcp/server/cleanErrorMessage")
local createFailure = require("@root/cli/mcp/server/createFailure")
local createSuccess = require("@root/cli/mcp/server/createSuccess")
local createToolResult = require("@root/cli/mcp/server/createToolResult")
local findTool = require("@root/cli/mcp/catalog/findTool")
local getToolArgv = require("@root/cli/mcp/catalog/getToolArgv")
local mcpTypes = require("@root/cli/mcp/types")
local protocol = require("@root/cli/mcp/server/protocol")

type Run = mcpTypes.Run

-- Command failures become tool results marked as errors so the client can show them to the model.
local function callTool(id: json.Value, params: json.Object, run: Run): json.Object
	local name = params.name

	if type(name) ~= "string" or findTool(name) == nil then
		return createFailure(id, protocol.errors.invalidParams, `Unknown tool: {tostring(name)}`)
	end

	local arguments = if params.arguments == nil then json.object({}) else json.asObject(params.arguments :: json.Value)

	if arguments == nil then
		return createFailure(id, protocol.errors.invalidParams, "Tool arguments must be an object")
	end

	local lines: { string } = {}
	local ok, message = pcall(function()
		run(getToolArgv(name, arguments), function(line: string)
			table.insert(lines, line)
		end)
	end)

	if ok then
		return createSuccess(id, createToolResult(table.concat(lines, "\n"), false))
	end

	return createSuccess(id, createToolResult(cleanErrorMessage(message), true))
end

return callTool
