local json = require("@std/json")
local test = require("@std/test")

local buildTools = require("@root/cli/mcp/catalog/buildTools")
local cli = require("@root/cli")
local getItem = require("@root/canvas/items/getItem")
local getVersion = require("@root/common/getVersion")
local handleMessage = require("@root/cli/mcp/server/handleMessage")
local loadDoc = require("@root/storage/canvases/loadDoc")
local mcpTypes = require("@root/cli/mcp/types")
local testing = require("@root/testing")
local writeDoc = require("@root/storage/canvases/writeDoc")

local need = assert
local TOOLS = buildTools(cli.describe())

local function runner(dir: string): mcpTypes.Run
	return function(argv: { string }, write: (string) -> ())
		cli.execute(argv, {
			dataDir = dir,
			write = write,
			now = function()
				return "2026-10-04T00:00:00Z"
			end,
			-- Matches mcp start, which keeps serving when a command reports
			-- findings through its status.
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
		assert(handleMessage(request(1, "tools/call", json.object({ name = name, arguments = arguments })), TOOLS, run))
	return assert(json.asObject(response.result))
end

local function firstText(result: json.Object): string
	local content = assert(json.asArray(result.content))
	local first = assert(json.asObject(content[1]))
	return first.text :: string
end

test.case("initialize negotiates a protocol version and advertises tools", function(assert)
	local run = runner(testing.directory("mcp-initialize"))
	local response =
		need(handleMessage(request(1, "initialize", json.object({ protocolVersion = "2025-06-18" })), TOOLS, run))
	local result = need(json.asObject(response.result))
	local capabilities = need(json.asObject(result.capabilities))
	assert.eq(response.id, 1)
	assert.eq(result.protocolVersion, "2025-06-18")
	assert.neq(json.asObject(capabilities.tools), nil)

	local newer =
		need(handleMessage(request(2, "initialize", json.object({ protocolVersion = "2099-01-01" })), TOOLS, run))
	assert.eq(need(json.asObject(newer.result)).protocolVersion, "2025-11-25")
end)

test.case("initialize reports the same version and commit that orion --version prints", function(assert)
	local run = runner(testing.directory("mcp-server-version"))
	local response = need(handleMessage(request(1, "initialize", json.object({})), TOOLS, run))
	local serverInfo = need(json.asObject(need(json.asObject(response.result)).serverInfo))

	assert.eq(serverInfo.version, getVersion())
end)

test.case("a stale server answers each request with an update error instead of tools", function(assert)
	local run = runner(testing.directory("mcp-stale-request"))
	local response = need(handleMessage(request(7, "tools/list"), TOOLS, run, true))
	local failure = need(json.asObject(response.error))

	assert.eq(response.id, 7)
	assert.eq(response.result, nil)
	assert.eq(failure.code, -32000)
	assert.strContains(failure.message :: string, "Reconnect the MCP server")
end)

test.case("initialize says what Orion is and where a card's branch goes", function(assert)
	local run = runner(testing.directory("mcp-instructions"))
	local response = need(handleMessage(request(1, "initialize", json.object({})), TOOLS, run))
	local instructions = need(json.asObject(response.result)).instructions :: string

	assert.strContains(instructions, "canvas")
	assert.strContains(instructions, "orion_canvas_list")
	assert.strContains(instructions, "orion_node_show")
	assert.strContains(instructions, "orion_card_set")
	assert.strContains(instructions, "branch:<owner>/<repo>@<branch>")
end)

test.case("tools round-trip through the CLI and workspace storage", function(assert)
	local run = runner(testing.directory("mcp-round-trip"))

	local listed = need(handleMessage(request(1, "tools/list"), TOOLS, run))
	local tools = need(json.asArray(need(json.asObject(listed.result)).tools))
	assert.eq(#tools > 10, true)

	local created = call(run, "orion_canvas_create", json.object({ name = "sample", label = "Sample" }))
	assert.eq(created.isError, nil)

	local added = call(run, "orion_card_create", json.object({ label = "MCP smoke test", canvas = "sample" }))
	assert.eq(added.isError, nil)
	local item = need(json.asObject(need(json.asObject(json.deserialize(firstText(added)) :: json.Value)).item))
	assert.eq(item.label, "MCP smoke test")

	local shown = call(run, "orion_node_show", json.object({ canvas = "sample", id = item.id }))
	assert.eq(shown.isError, nil)
	assert.strContains(firstText(shown), "MCP smoke test")

	local missing = call(run, "orion_node_show", json.object({ canvas = "sample", id = "missing" }))
	assert.eq(missing.isError, true)
	assert.eq(string.find(firstText(missing), "%.luau:%d+:"), nil)
	local failure = need(json.asObject(need(json.asObject(json.deserialize(firstText(missing)) :: json.Value)).error))
	assert.eq(failure.code, "missing-item")
	assert.eq(failure.message, 'no item or group with id "missing"')
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
	writeDoc(dir, testing.createDoc({ group, first, second }))
	local run = runner(dir)

	local clean = call(run, "orion_canvas_check", json.object({ group = "ws" }))
	assert.eq(clean.isError, nil)
	assert.eq(#need(json.asArray(json.deserialize(firstText(clean)) :: json.Value)), 0)

	local preview = call(run, "orion_group_tidy", json.object({ ids = { "ws" }, dryRun = true }))
	assert.eq(preview.isError, nil)
	assert.eq(getItem(loadDoc(dir), "ws").data.layout, nil)

	local tidied = call(run, "orion_group_tidy", json.object({ ids = { "ws" }, ifRevision = 0 }))
	assert.eq(tidied.isError, nil)
	local report = need(json.asObject(json.deserialize(firstText(tidied)) :: json.Value))
	assert.eq(report.appConnected, false)
	assert.eq(getItem(loadDoc(dir), "ws").data.layout, "refit")

	local stale = call(run, "orion_group_tidy", json.object({ ids = { "ws" }, ifRevision = 0 }))
	assert.eq(stale.isError, true)
	assert.strContains(firstText(stale), "revision changed")
	assert.strContains(firstText(stale), '"code":"revision-conflict"')

	local checked = call(run, "orion_canvas_check", json.object({}))
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
		handleMessage(
			request(1, "tools/call", json.object({ name = "orion_nope", arguments = json.object({}) })),
			TOOLS,
			run
		)
	)
	assert.eq(need(json.asObject(unknownTool.error)).code, -32602)

	local unknownMethod = need(handleMessage(request(2, "resources/list"), TOOLS, run))
	assert.eq(need(json.asObject(unknownMethod.error)).code, -32601)

	local parse = need(handleMessage("{not json", TOOLS, run))
	assert.eq(need(json.asObject(parse.error)).code, -32700)
	assert.eq(parse.id, json.null)

	assert.eq(
		handleMessage(
			json.serialize(json.object({ jsonrpc = "2.0", method = "notifications/initialized" })),
			TOOLS,
			run
		),
		nil
	)
end)

test.case("an old tool or argument name still calls the tool, and tools/list leaves it out", function(assert)
	local tools = buildTools(cli.describe(), {
		{ kind = "command", from = "card new", to = "card create", added = "2026-10-19", pr = 1 },
		{ kind = "option", command = "card create", from = "folder", to = "group", added = "2026-10-19", pr = 1 },
	})
	local dir = testing.directory("mcp-aliases")
	writeDoc(dir, testing.createDoc({ testing.group("ws", "Release") }))
	local run = runner(dir)

	local listed = need(handleMessage(request(1, "tools/list"), tools, run))
	local names: { [string]: boolean } = {}

	for _, tool in need(json.asArray(need(json.asObject(listed.result)).tools)) do
		names[need(json.asObject(tool)).name :: string] = true
	end

	assert.eq(names.orion_card_create, true)
	assert.eq(names.orion_card_new, nil)

	local response = need(
		handleMessage(
			request(
				2,
				"tools/call",
				json.object({ name = "orion_card_new", arguments = json.object({ label = "Old", folder = "ws" }) })
			),
			tools,
			run
		)
	)
	local result = need(json.asObject(response.result))
	assert.eq(result.isError, nil)
	local item = need(json.asObject(need(json.asObject(json.deserialize(firstText(result)) :: json.Value)).item))
	assert.eq(item.label, "Old")
	assert.eq(item.group, "ws")

	local both = need(handleMessage(
		request(
			3,
			"tools/call",
			json.object({
				name = "orion_card_create",
				arguments = json.object({ label = "Both", folder = "ws", group = "ws" }),
			})
		),
		tools,
		run
	))
	assert.strContains(firstText(need(json.asObject(both.result))), "folder is now group")
end)

test.case("hooks hear the client's name and each tool call under its current name", function(assert)
	local run = runner(testing.directory("mcp-hooks"))
	local clientName: string? = nil
	local calls: { { name: string, failed: boolean } } = {}
	local hooks: mcpTypes.Hooks = {
		onConnected = function(name: string?)
			clientName = name
		end,
		onToolCalled = function(name: string, durationMs: number, failed: boolean)
			assert.eq(durationMs >= 0, true)
			table.insert(calls, { name = name, failed = failed })
		end,
	}
	local params = json.object({ protocolVersion = "2025-06-18", clientInfo = json.object({ name = "claude-code" }) })

	handleMessage(request(1, "initialize", params), TOOLS, run, false, hooks)
	handleMessage(
		request(2, "tools/call", json.object({ name = "orion_card_list", arguments = json.object({}) })),
		TOOLS,
		run,
		false,
		hooks
	)
	handleMessage(
		request(3, "tools/call", json.object({ name = "orion_node_show", arguments = json.object({ id = "missing" }) })),
		TOOLS,
		run,
		false,
		hooks
	)

	assert.eq(clientName, "claude-code")
	assert.eq(#calls, 2)
	assert.eq(calls[1].name, "orion_card_list")
	assert.eq(calls[1].failed, false)
	assert.eq(calls[2].failed, true)
end)
