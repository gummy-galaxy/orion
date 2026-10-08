local json = require("@std/json")
local test = require("@std/test")

local cli = require("@root/cli")
local server = require("@root/cli/mcp/server")
local testing = require("@root/testing")

local need = assert

local function runner(dir: string): server.Run
	return function(argv: { string }, write: (string) -> ())
		cli.execute(argv, {
			dataDir = dir,
			write = write,
			now = function()
				return "2026-10-04T00:00:00Z"
			end,
		})
	end
end

local function request(id: number, method: string, params: json.Object?): string
	local message = json.object({ jsonrpc = "2.0", id = id, method = method })

	if params then
		message.params = params
	end

	return json.serialize(message)
end

local function call(run: server.Run, name: string, arguments: json.Object): json.Object
	local response =
		assert(server.handle(request(1, "tools/call", json.object({ name = name, arguments = arguments })), run))
	return assert(json.asObject(response.result))
end

local function firstText(result: json.Object): string
	local content = assert(json.asArray(result.content))
	local first = assert(json.asObject(content[1]))
	return first.text :: string
end

test.case("initialize negotiates a protocol version and advertises tools", function(assert)
	local run = runner(testing.directory("mcp-initialize"))
	local response = need(server.handle(request(1, "initialize", json.object({ protocolVersion = "2025-06-18" })), run))
	local result = need(json.asObject(response.result))
	local capabilities = need(json.asObject(result.capabilities))
	assert.eq(response.id, 1)
	assert.eq(result.protocolVersion, "2025-06-18")
	assert.neq(json.asObject(capabilities.tools), nil)

	local newer = need(server.handle(request(2, "initialize", json.object({ protocolVersion = "2099-01-01" })), run))
	assert.eq(need(json.asObject(newer.result)).protocolVersion, "2025-11-25")
end)

test.case("tools round-trip through the CLI and workspace storage", function(assert)
	local run = runner(testing.directory("mcp-round-trip"))

	local listed = need(server.handle(request(1, "tools/list"), run))
	local tools = need(json.asArray(need(json.asObject(listed.result)).tools))
	assert.eq(#tools > 10, true)

	local created =
		call(run, "orion_create_workspace", json.object({ name = "sample", label = "Sample", owner = "vocksel" }))
	assert.eq(created.isError, nil)

	local added = call(run, "orion_add_item", json.object({ title = "MCP smoke test", workspace = "sample" }))
	assert.eq(added.isError, nil)
	local item = need(json.asObject(json.deserialize(firstText(added)) :: json.Value))
	assert.eq(item.label, "MCP smoke test")

	local shown = call(run, "orion_inspect", json.object({ view = "show", workspace = "sample", id = item.id }))
	assert.eq(shown.isError, nil)
	assert.strContains(firstText(shown), "MCP smoke test")

	local missing = call(run, "orion_inspect", json.object({ view = "show", workspace = "sample", id = "missing" }))
	assert.eq(missing.isError, true)
	assert.eq(string.find(firstText(missing), "%.luau:%d+:"), nil)
end)

test.case("protocol errors use JSON-RPC error codes", function(assert)
	local run = runner(testing.directory("mcp-errors"))

	local unknownTool = need(
		server.handle(request(1, "tools/call", json.object({ name = "orion_nope", arguments = json.object({}) })), run)
	)
	assert.eq(need(json.asObject(unknownTool.error)).code, -32602)

	local unknownMethod = need(server.handle(request(2, "resources/list"), run))
	assert.eq(need(json.asObject(unknownMethod.error)).code, -32601)

	local parse = need(server.handle("{not json", run))
	assert.eq(need(json.asObject(parse.error)).code, -32700)
	assert.eq(parse.id, json.null)

	assert.eq(
		server.handle(json.serialize(json.object({ jsonrpc = "2.0", method = "notifications/initialized" })), run),
		nil
	)
end)

test.case("serve answers each line, however stdin splits it, and stops at end of input", function(assert)
	local run = runner(testing.directory("mcp-serve"))
	local first, second = request(1, "ping"), request(2, "ping")
	local chunks = {
		`{first}\n{string.sub(second, 1, 10)}`,
		`{string.sub(second, 11)}\r\n\n`,
	}
	local written: { string } = {}

	server.serve(function()
		local chunk = table.remove(chunks, 1)

		if chunk == nil then
			error("end of file")
		end

		return chunk
	end, function(text: string)
		table.insert(written, text)
	end, run)

	assert.eq(#written, 2)
	assert.eq(string.sub(written[1], -1), "\n")
	assert.eq(need(json.asObject(json.deserialize(written[2]) :: json.Value)).id, 2)
end)
