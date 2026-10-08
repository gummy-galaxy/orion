local json = require("@std/json")

local catalog = require("@root/cli/mcp/catalog")

export type Run = (argv: { string }, write: (string) -> ()) -> ()

local SERVER_VERSION = "0.1.0"
local PROTOCOL_VERSIONS = { "2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05" }

local PARSE_ERROR = -32700
local INVALID_REQUEST = -32600
local METHOD_NOT_FOUND = -32601
local INVALID_PARAMS = -32602

local function failure(id: json.Value, code: number, message: string): json.Object
	return json.object({
		jsonrpc = "2.0",
		id = if id == nil then json.null else id,
		error = json.object({ code = code, message = message }),
	})
end

local function success(id: json.Value, result: json.Object): json.Object
	return json.object({ jsonrpc = "2.0", id = id, result = result })
end

local function text(value: string, isError: boolean): json.Object
	local result = json.object({ content = { json.object({ type = "text", text = value }) } })

	if isError then
		result.isError = true
	end

	return result
end

local function cleanError(message: unknown): string
	return (tostring(message):gsub("^[^\n]-:%d+: ", "", 1))
end

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

local function callTool(id: json.Value, params: json.Object, run: Run): json.Object
	local name = params.name

	if type(name) ~= "string" or not catalog.has(name) then
		return failure(id, INVALID_PARAMS, `Unknown tool: {tostring(name)}`)
	end

	local arguments = if params.arguments == nil then json.object({}) else json.asObject(params.arguments :: json.Value)

	if arguments == nil then
		return failure(id, INVALID_PARAMS, "Tool arguments must be an object")
	end

	local lines: { string } = {}
	local ok, message = pcall(function()
		run(catalog.argv(name, arguments), function(line: string)
			table.insert(lines, line)
		end)
	end)

	if ok then
		return success(id, text(table.concat(lines, "\n"), false))
	end

	return success(id, text(cleanError(message), true))
end

local function handle(line: string, run: Run): json.Object?
	local decoded, value = pcall(json.deserialize, line)

	if not decoded then
		return failure(nil, PARSE_ERROR, "Parse error")
	end

	local message = json.asObject(value :: json.Value)

	if message == nil or message.jsonrpc ~= "2.0" or type(message.method) ~= "string" then
		return failure(if message then message.id else nil, INVALID_REQUEST, "Invalid request")
	end

	local id = message.id

	if id == nil then
		return nil
	end

	local params = if message.params == nil then json.object({}) else json.asObject(message.params :: json.Value)

	if params == nil then
		return failure(id, INVALID_PARAMS, "Params must be an object")
	end

	local method = message.method

	if method == "initialize" then
		return success(id, initialize(params))
	elseif method == "ping" then
		return success(id, json.object({}))
	elseif method == "tools/list" then
		return success(id, json.object({ tools = catalog.schema().tools }))
	elseif method == "tools/call" then
		return callTool(id, params, run)
	end

	return failure(id, METHOD_NOT_FOUND, `Method not found: {method}`)
end

-- Reads stdin in chunks that may hold several messages or part of one, and stops at end of input.
local function serve(read: () -> string, write: (string) -> (), run: Run)
	local pending = ""

	while true do
		local ok, chunk = pcall(read)

		if not ok or chunk == "" then
			return
		end

		pending ..= chunk

		while true do
			local newline = string.find(pending, "\n", 1, true)

			if newline == nil then
				break
			end

			local line = string.gsub(string.sub(pending, 1, newline - 1), "\r$", "")
			pending = string.sub(pending, newline + 1)

			if string.find(line, "%S") then
				local response = handle(line, run)

				if response then
					write(json.serialize(response) .. "\n")
				end
			end
		end
	end
end

return table.freeze({
	handle = handle,
	serve = serve,
})
