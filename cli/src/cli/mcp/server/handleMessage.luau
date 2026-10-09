local json = require("@std/json")

local describeTools = require("@root/cli/mcp/catalog/describeTools")
local findTool = require("@root/cli/mcp/catalog/findTool")
local getToolArgv = require("@root/cli/mcp/catalog/getToolArgv")
local mcpTypes = require("@root/cli/mcp/types")

type Run = mcpTypes.Run

local SERVER_VERSION = "0.1.0"
local PROTOCOL_VERSIONS = { "2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05" }

local PARSE_ERROR = -32700
local INVALID_REQUEST = -32600
local METHOD_NOT_FOUND = -32601
local INVALID_PARAMS = -32602

local function createFailure(id: json.Value, code: number, message: string): json.Object
	return json.object({
		jsonrpc = "2.0",
		id = if id == nil then json.null else id,
		error = json.object({ code = code, message = message }),
	})
end

local function createSuccess(id: json.Value, result: json.Object): json.Object
	return json.object({ jsonrpc = "2.0", id = id, result = result })
end

local function createToolResult(text: string, isError: boolean): json.Object
	local result = json.object({ content = { json.object({ type = "text", text = text }) } })

	if isError then
		result.isError = true
	end

	return result
end

-- Drops the file and line prefix Luau adds to error messages.
local function cleanErrorMessage(message: unknown): string
	return (tostring(message):gsub("^[^\n]-:%d+: ", "", 1))
end

-- Agrees to the client's protocol version when the server speaks it, and offers the newest otherwise.
local function initialize(params: json.Object): json.Object
	local requested = params.protocolVersion
	local version = PROTOCOL_VERSIONS[1]

	if type(requested) == "string" and table.find(PROTOCOL_VERSIONS, requested) then
		version = requested
	end

	return json.object({
		protocolVersion = version,
		capabilities = json.object({ tools = json.object({ listChanged = false }) }),
		serverInfo = json.object({ name = "orion", version = SERVER_VERSION }),
	})
end

-- Command failures become tool results marked as errors so the client can show them to the model.
local function callTool(id: json.Value, params: json.Object, run: Run): json.Object
	local name = params.name

	if type(name) ~= "string" or findTool(name) == nil then
		return createFailure(id, INVALID_PARAMS, `Unknown tool: {tostring(name)}`)
	end

	local arguments = if params.arguments == nil then json.object({}) else json.asObject(params.arguments :: json.Value)

	if arguments == nil then
		return createFailure(id, INVALID_PARAMS, "Tool arguments must be an object")
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

-- Answers one JSON-RPC message. Notifications get no response.
local function handleMessage(line: string, run: Run): json.Object?
	local decoded, value = pcall(json.deserialize, line)

	if not decoded then
		return createFailure(nil, PARSE_ERROR, "Parse error")
	end

	local message = json.asObject(value :: json.Value)

	if message == nil or message.jsonrpc ~= "2.0" or type(message.method) ~= "string" then
		return createFailure(if message then message.id else nil, INVALID_REQUEST, "Invalid request")
	end

	local id = message.id

	if id == nil then
		return nil
	end

	local params = if message.params == nil then json.object({}) else json.asObject(message.params :: json.Value)

	if params == nil then
		return createFailure(id, INVALID_PARAMS, "Params must be an object")
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

	return createFailure(id, METHOD_NOT_FOUND, `Method not found: {method}`)
end

return handleMessage
