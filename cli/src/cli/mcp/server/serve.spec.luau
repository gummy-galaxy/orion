local json = require("@std/json")
local test = require("@std/test")

local cli = require("@root/cli")
local mcpTypes = require("@root/cli/mcp/types")
local serve = require("@root/cli/mcp/server/serve")
local testing = require("@root/testing")

local need = assert

local function runner(dir: string): mcpTypes.Run
	return function(argv: { string }, write: (string) -> ())
		cli.execute(argv, { dataDir = dir, write = write })
	end
end

local function request(id: number, method: string): string
	return json.serialize(json.object({ jsonrpc = "2.0", id = id, method = method }))
end

test.case("serve answers each line, however stdin splits it, and stops at end of input", function(assert)
	local run = runner(testing.directory("mcp-serve"))
	local first, second = request(1, "ping"), request(2, "ping")
	local chunks = {
		`{first}\n{string.sub(second, 1, 10)}`,
		`{string.sub(second, 11)}\r\n\n`,
	}
	local written: { string } = {}

	serve(function()
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

test.case("serve answers the message that finds the binary stale with an update error, then stops", function(assert)
	local run = runner(testing.directory("mcp-serve-stale"))
	local chunks = { `{request(1, "ping")}\n{request(2, "ping")}\n{request(3, "ping")}\n` }
	local written: { string } = {}
	local stale = false

	serve(
		function()
			local chunk = table.remove(chunks, 1)

			if chunk == nil then
				error("end of file")
			end

			return chunk
		end,
		function(text: string)
			table.insert(written, text)
			stale = true
		end,
		run,
		function()
			return stale
		end
	)

	assert.eq(#written, 2)
	assert.eq(need(json.asObject(json.deserialize(written[1]) :: json.Value)).id, 1)

	local answer = need(json.asObject(json.deserialize(written[2]) :: json.Value))
	local failure = need(json.asObject(answer.error))
	assert.eq(answer.id, 2)
	assert.eq(failure.code, -32000)
	assert.strContains(failure.message :: string, "Reconnect the MCP server")
end)
