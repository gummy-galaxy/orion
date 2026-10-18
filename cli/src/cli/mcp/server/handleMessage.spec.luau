local json = require("@std/json")
local test = require("@std/test")

local cli = require("@root/cli")
local getItem = require("@root/graph/getItem")
local getVersion = require("@root/getVersion")
local handleMessage = require("@root/cli/mcp/server/handleMessage")
local mcpTypes = require("@root/cli/mcp/types")
local store = require("@root/store")
local testing = require("@root/testing")

local need = assert

local function runner(dir: string): mcpTypes.Run
	return function(argv: { string }, write: (string) -> ())
		cli.execute(argv, {
			dataDir = dir,
			write = write,
			now = function()
				return "2026-10-04T00:00:00Z"
			end,
			-- Matches mcp start, which keeps serving when a command reports findings through its status.
			exit = function(_code: number) end,
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

local function call(run: mcpTypes.Run, name: string, arguments: json.Object): json.Object
	local response =
		assert(handleMessage(request(1, "tools/call", json.object({ name = name, arguments = arguments })), run))
	return assert(json.asObject(response.result))
end

local function firstText(result: json.Object): string
	local content = assert(json.asArray(result.content))
	local first = assert(json.asObject(content[1]))
	return first.text :: string
end

test.case("initialize negotiates a protocol version and advertises tools", function(assert)
	local run = runner(testing.directory("mcp-initialize"))
	local response = need(handleMessage(request(1, "initialize", json.object({ protocolVersion = "2025-06-18" })), run))
	local result = need(json.asObject(response.result))
	local capabilities = need(json.asObject(result.capabilities))
	assert.eq(response.id, 1)
	assert.eq(result.protocolVersion, "2025-06-18")
	assert.neq(json.asObject(capabilities.tools), nil)

	local newer = need(handleMessage(request(2, "initialize", json.object({ protocolVersion = "2099-01-01" })), run))
	assert.eq(need(json.asObject(newer.result)).protocolVersion, "2025-11-25")
end)

test.case("initialize reports the same version and commit that orion --version prints", function(assert)
	local run = runner(testing.directory("mcp-server-version"))
	local response = need(handleMessage(request(1, "initialize", json.object({})), run))
	local serverInfo = need(json.asObject(need(json.asObject(response.result)).serverInfo))

	assert.eq(serverInfo.version, getVersion())
end)

test.case("a stale server answers each request with an update error instead of tools", function(assert)
	local run = runner(testing.directory("mcp-stale-request"))
	local response = need(handleMessage(request(7, "tools/list"), run, true))
	local failure = need(json.asObject(response.error))

	assert.eq(response.id, 7)
	assert.eq(response.result, nil)
	assert.eq(failure.code, -32000)
	assert.strContains(failure.message :: string, "Reconnect the MCP server")
end)

test.case("initialize says what Orion is and where a card's branch goes", function(assert)
	local run = runner(testing.directory("mcp-instructions"))
	local response = need(handleMessage(request(1, "initialize", json.object({})), run))
	local instructions = need(json.asObject(response.result)).instructions :: string

	assert.strContains(instructions, "canvas")
	assert.strContains(instructions, "orion_canvases")
	assert.strContains(instructions, "orion_inspect")
	assert.strContains(instructions, "orion_update_item")
	assert.strContains(instructions, "branch:<owner>/<repo>@<branch>")
end)

test.case("tools round-trip through the CLI and workspace storage", function(assert)
	local run = runner(testing.directory("mcp-round-trip"))

	local listed = need(handleMessage(request(1, "tools/list"), run))
	local tools = need(json.asArray(need(json.asObject(listed.result)).tools))
	assert.eq(#tools > 10, true)

	local created = call(run, "orion_create_canvas", json.object({ name = "sample", label = "Sample" }))
	assert.eq(created.isError, nil)

	local added = call(run, "orion_add_item", json.object({ title = "MCP smoke test", canvas = "sample" }))
	assert.eq(added.isError, nil)
	local item = need(json.asObject(json.deserialize(firstText(added)) :: json.Value))
	assert.eq(item.label, "MCP smoke test")

	local shown = call(run, "orion_inspect", json.object({ view = "show", canvas = "sample", id = item.id }))
	assert.eq(shown.isError, nil)
	assert.strContains(firstText(shown), "MCP smoke test")

	local missing = call(run, "orion_inspect", json.object({ view = "show", canvas = "sample", id = "missing" }))
	assert.eq(missing.isError, true)
	assert.eq(string.find(firstText(missing), "%.luau:%d+:"), nil)
end)

test.case("tidy marks a group and check reports it waiting for layout without stopping the server", function(assert)
	local group = testing.group("ws", "Release")
	group.width = 600
	group.height = 300
	local first = testing.task("ci", "Report release health", "todo", "ws")
	first.position = { x = 32, y = 78 }
	local second = testing.task("pub", "Publish", "todo", "ws")
	second.position = { x = 280, y = 78 }
	local dir = testing.directory("mcp-layout")
	store.write(dir, testing.createDoc({ group, first, second }))
	local run = runner(dir)

	local clean = call(run, "orion_check", json.object({ group = "ws" }))
	assert.eq(clean.isError, nil)
	assert.eq(#need(json.asArray(json.deserialize(firstText(clean)) :: json.Value)), 0)

	local preview = call(run, "orion_tidy", json.object({ ids = { "ws" }, dryRun = true }))
	assert.eq(preview.isError, nil)
	assert.eq(getItem(store.load(dir), "ws").data.layout, nil)

	local tidied = call(run, "orion_tidy", json.object({ ids = { "ws" }, ifRevision = 0 }))
	assert.eq(tidied.isError, nil)
	local report = need(json.asObject(json.deserialize(firstText(tidied)) :: json.Value))
	assert.eq(report.appConnected, false)
	assert.eq(getItem(store.load(dir), "ws").data.layout, "refit")

	local stale = call(run, "orion_tidy", json.object({ ids = { "ws" }, ifRevision = 0 }))
	assert.eq(stale.isError, true)
	assert.strContains(firstText(stale), "revision changed")

	local checked = call(run, "orion_check", json.object({}))
	assert.eq(checked.isError, nil)
	local issues = need(json.asArray(json.deserialize(firstText(checked)) :: json.Value))
	assert.eq(#issues, 1)
	local issue = need(json.asObject(issues[1]))
	assert.eq(issue.kind, "waiting-for-layout")
	assert.eq(issue.ids, { "ws" })
end)

test.case("protocol errors use JSON-RPC error codes", function(assert)
	local run = runner(testing.directory("mcp-errors"))

	local unknownTool = need(
		handleMessage(request(1, "tools/call", json.object({ name = "orion_nope", arguments = json.object({}) })), run)
	)
	assert.eq(need(json.asObject(unknownTool.error)).code, -32602)

	local unknownMethod = need(handleMessage(request(2, "resources/list"), run))
	assert.eq(need(json.asObject(unknownMethod.error)).code, -32601)

	local parse = need(handleMessage("{not json", run))
	assert.eq(need(json.asObject(parse.error)).code, -32700)
	assert.eq(parse.id, json.null)

	assert.eq(
		handleMessage(json.serialize(json.object({ jsonrpc = "2.0", method = "notifications/initialized" })), run),
		nil
	)
end)
