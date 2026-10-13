local json = require("@std/json")
local net = require("@lute/net/server")
local test = require("@std/test")

local merge = require("@root/server/routes/merge")
local types = require("@root/types")

local URL = "https://github.com/vocksel/orion/pull/142"
local loop = {
	getStatus = function()
		return json.object({})
	end,
	run = function()
		return json.object({})
	end,
}

local function request(method: string, body: json.Object?): net.ReceivedRequest
	return {
		method = method,
		path = "/api/merge",
		body = if body then json.serialize(body) else "",
		query = {} :: { [string]: string },
		headers = {},
	}
end

test.case("merge route merges a pull request at the head the card showed", function(assert)
	local commands = {} :: { { string } }
	local function run(argv: { string }): types.CommandResult
		table.insert(commands, argv)
		return { ok = true, exitCode = 0, stdout = "SQUASH", stderr = "" }
	end

	local response = merge.handle(request("POST", json.object({ url = URL, head = "abc123" })), loop, run)

	assert.eq(response.status, 200)
	assert.eq(table.concat(commands[2], " "), `gh pr merge {URL} --squash --match-head-commit abc123`)
end)

test.case("merge route rejects other methods and malformed input before running anything", function(assert)
	local calls = 0
	local function run(): types.CommandResult
		calls += 1
		return { ok = true, exitCode = 0, stdout = "", stderr = "" }
	end

	assert.eq(merge.handle(request("GET"), loop, run).status, 405)
	assert.eq(merge.handle(request("POST", json.object({ url = URL })), loop, run).status, 400)
	assert.eq(merge.handle(request("POST", json.object({ url = `{URL};x`, head = "abc" })), loop, run).status, 400)
	assert.eq(merge.handle(request("POST", json.object({ url = URL, head = "--admin" })), loop, run).status, 400)
	assert.eq(calls, 0)
end)
