local json = require("@std/json")
local test = require("@std/test")

local store = require("@root/store")
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

test.case("sync ticks poll and sweep quietly between full passes and write only what changed", function(assert)
	local root = testing.createHarness("sync-tick")
	local dir = store.getWorkspaceDir(root, "default")
	local now = 100
	local calls: { string } = {}
	local states: { string } = {}
	local loop = sync.create(root, "default", function(status: json.Object)
		table.insert(states, status.state :: string)
	end, function(argv)
		local query = argv[#argv]

		if argv[3] == "--include" then
			table.insert(calls, "poll")
			return testing.result(
				false,
				"HTTP/2.0 304 Not Modified\nLast-Modified: Sun, 18 Oct 2026 15:53:33 GMT\nX-Poll-Interval: 60\n\n",
				"gh: HTTP 304"
			)
		elseif query:find("pullRequests(first:", 1, true) then
			table.insert(calls, "authored")
			return testing.result(
				true,
				[[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[],"pageInfo":{"hasNextPage":false}}}}}]]
			)
		elseif query:find("{ updatedAt }", 1, true) then
			table.insert(calls, "sweep")
			return testing.result(true, [[{"data":{"p1":{"pullRequest":{"updatedAt":"2026-10-18T00:00:00Z"}}}}]])
		end

		table.insert(calls, "full")
		return testing.result(
			true,
			[[{"data":{"p1":{"pullRequest":{"number":658,"state":"OPEN","url":"u","updatedAt":"2026-10-18T00:00:00Z"}}}}]]
		)
	end, function()
		return now
	end)

	loop.tick()
	local revision = store.load(dir).revision
	assert.eq(table.concat(calls, ","), "authored,full")
	assert.eq(table.concat(states, ","), "running,idle")

	table.clear(calls)
	table.clear(states)
	now += 30
	loop.tick()
	assert.eq(#calls, 0)

	now += 31
	loop.tick()
	assert.eq(table.concat(calls, ","), "poll")
	assert.eq(table.concat(states, ","), "idle")

	table.clear(calls)
	now += 60
	loop.tick()
	assert.eq(table.concat(calls, ","), "poll,sweep,authored")
	assert.eq(store.load(dir).revision, revision)
	assert.eq(table.find(states, "running"), nil)

	table.clear(calls)
	now = 100 + 15 * 60
	loop.tick()
	assert.eq(table.concat(calls, ","), "authored,full")
	assert.eq(store.load(dir).revision, revision + 1)
end)

test.case("an unforced sync request sweeps once a full pass has run", function(assert)
	local root = testing.createHarness("sync-request")
	local now = 100
	local calls: { string } = {}
	local loop = sync.create(root, "default", function(_status: json.Object) end, function(argv)
		local query = argv[#argv]

		if argv[3] == "--include" then
			table.insert(calls, "poll")
			return testing.result(true, "HTTP/2.0 200 OK\n\n[]")
		elseif query:find("{ updatedAt }", 1, true) then
			table.insert(calls, "sweep")
		elseif query:find("pullRequests(first:", 1, true) then
			table.insert(calls, "authored")
			return testing.result(
				true,
				[[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[],"pageInfo":{"hasNextPage":false}}}}}]]
			)
		else
			table.insert(calls, "full")
		end

		return testing.result(true, [[{"data":{}}]])
	end, function()
		return now
	end)

	loop.run()
	assert.eq(table.find(calls, "full") ~= nil, true)
	table.clear(calls)
	now += 61
	loop.run()
	assert.eq(table.find(calls, "sweep") ~= nil, true)
	assert.eq(table.find(calls, "full"), nil)
end)
