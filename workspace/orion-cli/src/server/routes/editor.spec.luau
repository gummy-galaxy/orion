local json = require("@std/json")
local net = require("@lute/net/server")
local test = require("@std/test")

local editor = require("@root/server/routes/editor")
local types = require("@root/types")

local URL = "https://github.com/vocksel/orion/pull/142"

local function request(method: string, body: json.Object?): net.ReceivedRequest
	return {
		method = method,
		path = "/api/editor",
		body = if body then json.serialize(body) else "",
		query = {} :: { [string]: string },
		headers = {},
	}
end

test.case("editor reports availability and passes the exact PR URL to Hop", function(assert)
	local commands = {} :: { { string } }
	local function run(argv: { string }): types.CommandResult
		table.insert(commands, argv)
		return { ok = true, exitCode = 0, stdout = "", stderr = "" }
	end
	local availability = editor.handle(request("GET"), run)
	assert.eq(availability.status, 200)
	local state = json.asObject(json.deserialize(availability.body) :: json.Value)
	assert.eq(if state then state.available else nil, true)
	assert.eq(editor.handle(request("POST", json.object({ url = URL })), run).status, 200)
	assert.eq(table.concat(commands[3], " "), "which code")
	assert.eq(table.concat(commands[4], " "), "which hop")
	assert.eq(table.concat(commands[5], " "), `hop to {URL}`)
end)

test.case("editor rejects unsafe references and missing launchers", function(assert)
	local calls = 0
	local function missingHop(argv: { string }): types.CommandResult
		calls += 1
		return { ok = argv[2] ~= "hop", exitCode = 1, stdout = "", stderr = "" }
	end
	assert.eq(editor.handle(request("GET"), missingHop).body, [[{"available":false}]])
	assert.eq(
		editor.handle(request("POST", json.object({ url = "https://github.com/x/y/pull/1;open bad" })), missingHop).status,
		400
	)
	assert.eq(editor.handle(request("POST", json.object({ url = URL })), missingHop).status, 503)
	assert.eq(calls, 4)
end)
