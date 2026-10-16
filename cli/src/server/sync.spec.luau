local json = require("@std/json")
local test = require("@std/test")

local sync = require("@root/server/sync")
local testing = require("@root/testing")

test.case("sync throttles repeated requests and force bypasses the throttle", function(assert)
	local root = testing.createHarness("sync-throttle")
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

test.case("sync applies what it fetched and reports the part that failed", function(assert)
	local root = testing.createHarness("sync-partial")
	local loop = sync.create(root, "default", function(_status: json.Object) end, function(argv)
		local query = argv[#argv]

		if query:find("pullRequests(first:", 1, true) then
			return testing.result(false, "", "gh: HTTP 401")
		elseif query:find("viewer { login }", 1, true) then
			return testing.result(true, [[{"data":{"viewer":{"login":"vocksel"}}}]])
		end

		return testing.result(true, [[{"data":{}}]])
	end)

	local status = loop.run()
	assert.eq(status.state, "error")
	assert.strContains(status.message :: string, "Couldn't fetch your open pull requests")
	assert.eq(status.lastRun ~= nil, true)
end)
