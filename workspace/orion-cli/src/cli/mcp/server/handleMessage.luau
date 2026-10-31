local json = require("@std/json")
local time = require("@std/time")

local describeTools = require("@root/cli/mcp/catalog/describeTools")
local findTool = require("@root/cli/mcp/catalog/findTool")
local getToolArgv = require("@root/cli/mcp/catalog/getToolArgv")
local getVersion = require("@root/getVersion")
local mcpTypes = require("@root/cli/mcp/types")
local orientation = require("@root/cli/orientation")
local serializeFailure = require("@root/cli/serializeFailure")

type Hooks = mcpTypes.Hooks
type Run = mcpTypes.Run
type Tool = mcpTypes.Tool

local PROTOCOL_VERSIONS = { "2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05" }
-- Sent in the initialize response so clients know what Orion is before they
-- pick a tool.
local INSTRUCTIONS = table.concat(orientation.paragraphs, " ")

local PARSE_ERROR = -32700
local INVALID_REQUEST = -32600
local METHOD_NOT_FOUND = -32601
local INVALID_PARAMS = -32602
-- Implementation-defined server errors sit in -32000 to -32099.
local SERVER_UPDATED = -32000
local SERVER_UPDATED_MESSAGE =
	"Orion was updated while this MCP server was running. Reconnect the MCP server to use the new build."

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

-- Agrees to the client's protocol version when the server speaks it, and offers
-- the newest otherwise.
local function initialize(params: json.Object): json.Object
	local requested = params.protocolVersion
	local version = PROTOCOL_VERSIONS[1]

	if type(requested) == "string" and table.find(PROTOCOL_VERSIONS, requested) then
		version = requested
	end

	return json.object({
		protocolVersion = version,
		capabilities = json.object({ tools = json.object({ listChanged = false }) }),
		serverInfo = json.object({ name = "orion", version = getVersion() }),
		instructions = INSTRUCTIONS,
	})
end

-- Command failures become tool results marked as errors so the client can show
-- them to the model. Their text is the JSON error that --json prints, so a
-- failure's code reaches the model too.
local function callTool(id: json.Value, params: json.Object, tools: { Tool }, run: Run, hooks: Hooks?): json.Object
	local name = params.name
	local tool = if type(name) == "string" then findTool(tools, name) else nil

	if type(name) ~= "string" or tool == nil then
		return createFailure(id, INVALID_PARAMS, `Unknown tool: {tostring(name)}`)
	end

	local arguments = if params.arguments == nil then json.object({}) else json.asObject(params.arguments :: json.Value)

	if arguments == nil then
		return createFailure(id, INVALID_PARAMS, "Tool arguments must be an object")
	end

	local lines: { string } = {}
	local startedAt = time.now()
	local ok, message = pcall(function()
		run(getToolArgv(tools, name, arguments), function(line: string)
			table.insert(lines, line)
		end)
	end)

	if hooks and hooks.toolCalled then
		pcall(hooks.toolCalled, tool.name, math.floor(time.since(startedAt) * 1000), not ok)
	end

	if ok then
		return createSuccess(id, createToolResult(table.concat(lines, "\n"), false))
	end

	return createSuccess(id, createToolResult(serializeFailure(message), true))
end

-- Answers one JSON-RPC message, calling tools with run. Notifications get no
-- response. A stale server answers requests with an error.
local function handleMessage(line: string, tools: { Tool }, run: Run, stale: boolean?, hooks: Hooks?): json.Object?
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

	if stale then
		return createFailure(id, SERVER_UPDATED, SERVER_UPDATED_MESSAGE)
	end

	local params = if message.params == nil then json.object({}) else json.asObject(message.params :: json.Value)

	if params == nil then
		return createFailure(id, INVALID_PARAMS, "Params must be an object")
	end

	local method = message.method

	if method == "initialize" then
		if hooks and hooks.connected then
			local clientInfo = json.asObject(params.clientInfo :: json.Value)
			local clientName = if clientInfo and type(clientInfo.name) == "string" then clientInfo.name else nil
			pcall(hooks.connected, clientName)
		end

		return createSuccess(id, initialize(params))
	elseif method == "ping" then
		return createSuccess(id, json.object({}))
	elseif method == "tools/list" then
		return createSuccess(id, json.object({ tools = describeTools(tools) }))
	elseif method == "tools/call" then
		return callTool(id, params, tools, run, hooks)
	end

	return createFailure(id, METHOD_NOT_FOUND, `Method not found: {method}`)
end

return handleMessage
