local json = require("@std/json")
local test = require("@std/test")

local sync = require("@root/server/sync")
local testing = require("@root/testing")

test.case("sync throttles repeated requests and force bypasses the throttle", function(assert)
	local root = testing.harness("sync-throttle")
	local calls = 0
	local now = 100
	local loop = sync.create(root, "default", function(_status: json.Object) end, function(_argv)
		calls += 1
		error("offline")
	end, function()
		return now
	end)
	loop.run()
	local first = calls
	assert.that(first > 0)
	loop.run()
	assert.eq(calls, first)
	loop.run(true)
	assert.that(calls > first)
	now += 61
	local before = calls
	loop.run()
	assert.that(calls > before)
end)
