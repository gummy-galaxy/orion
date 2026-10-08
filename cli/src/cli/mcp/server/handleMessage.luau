local json = require("@std/json")

local callTool = require("@root/cli/mcp/server/callTool")
local createFailure = require("@root/cli/mcp/server/createFailure")
local createSuccess = require("@root/cli/mcp/server/createSuccess")
local describeTools = require("@root/cli/mcp/catalog/describeTools")
local initialize = require("@root/cli/mcp/server/initialize")
local mcpTypes = require("@root/cli/mcp/types")
local protocol = require("@root/cli/mcp/server/protocol")

type Run = mcpTypes.Run

-- Answers one JSON-RPC message. Notifications get no response.
local function handleMessage(line: string, run: Run): json.Object?
	local decoded, value = pcall(json.deserialize, line)

	if not decoded then
		return createFailure(nil, protocol.errors.parse, "Parse error")
	end

	local message = json.asObject(value :: json.Value)

	if message == nil or message.jsonrpc ~= "2.0" or type(message.method) ~= "string" then
		return createFailure(if message then message.id else nil, protocol.errors.invalidRequest, "Invalid request")
	end

	local id = message.id

	if id == nil then
		return nil
	end

	local params = if message.params == nil then json.object({}) else json.asObject(message.params :: json.Value)

	if params == nil then
		return createFailure(id, protocol.errors.invalidParams, "Params must be an object")
	end

	local method = message.method

	if method == "initialize" then
		return createSuccess(id, initialize(params))
	elseif method == "ping" then
		return createSuccess(id, json.object({}))
	elseif method == "tools/list" then
		return createSuccess(id, json.object({ tools = describeTools() }))
	elseif method == "tools/call" then
		return callTool(id, params, run)
	end

	return createFailure(id, protocol.errors.methodNotFound, `Method not found: {method}`)
end

return handleMessage
