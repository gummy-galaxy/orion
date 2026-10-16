local test = require("@std/test")

local collectPulls = require("@root/github/collectPulls")
local testing = require("@root/testing")

test.case("collect batches pull request lookups by host", function(assert)
	local doc = testing.createDoc({
		testing.task("public", "Public", "todo", nil, {
			repo = "flipbook-labs/flipbook",
			refs = { { source = "github", kind = "pull", key = "flipbook-labs/flipbook#1" } },
		}),
		testing.task("private", "Private", "todo", nil, {
			repo = "Roblox/avatar",
			refs = { { source = "github", kind = "pull", key = "github.example.com/Roblox/avatar#2" } },
		}),
	})
	local batches = {}
	collectPulls(doc, function(argv)
		local query = argv[#argv]

		if query:find("pullRequests(first:", 1, true) then
			return testing.result(true, [[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[]}}}}]])
		elseif query:find("search(query:", 1, true) then
			return testing.result(true, [[{"data":{"search":{"nodes":[]}}}]])
		end

		table.insert(batches, argv)
		return testing.result(true, [[{"data":{}}]])
	end, false)
	assert.eq(#batches, 2)
	local hosts: { [string]: boolean } = {}

	for _, argv in batches do
		if argv[3] == "--hostname" then
			hosts[argv[4]] = true
		else
			hosts["github.com"] = true
		end
	end

	assert.eq(hosts["github.com"], true)
	assert.eq(hosts["github.example.com"], true)
end)

local AUTHORED =
	[[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[{"number":7,"state":"OPEN","url":"u7","headRefName":"agent/branch","repository":{"name":"orion","owner":{"login":"vocksel"}}},{"number":8,"state":"OPEN","url":"u8","headRefName":"agent/other","repository":{"name":"orion","owner":{"login":"vocksel"}}}]}}}}]]

test.case("collect skips merged cards and fetches full state only for branch matches", function(assert)
	local doc = testing.createDoc({
		testing.task("merged", "Merged", "done", nil, {
			refs = { { source = "github", kind = "pull", key = "vocksel/orion#1", status = "merged" } },
		}),
		testing.task("open", "Open", "review", nil, {
			refs = { { source = "github", kind = "pull", key = "vocksel/orion#2", status = "open" } },
		}),
		testing.task("branch", "Branch work", "todo", nil, {
			refs = { { source = "hop", kind = "branch", key = "vocksel/orion@agent/branch" } },
		}),
	})
	local batches: { string } = {}
	local fetched = collectPulls(doc, function(argv)
		local query = argv[#argv]

		if query:find("pullRequests(first:", 1, true) then
			return testing.result(true, AUTHORED)
		end

		table.insert(batches, query)
		return testing.result(true, [[{"data":{}}]])
	end, false)

	assert.eq(#batches, 1)
	assert.eq(batches[1]:find("number: 1)", 1, true), nil)
	assert.strContains(batches[1], "number: 2)")
	assert.strContains(batches[1], "number: 7)")
	assert.eq(batches[1]:find("number: 8)", 1, true), nil)
	assert.eq(#fetched.authored, 2)
	assert.eq(#fetched.failures, 0)
end)

test.case("collect still refreshes cards when the authored list fails", function(assert)
	local doc = testing.createDoc({
		testing.task("open", "Open", "review", nil, {
			refs = { { source = "github", kind = "pull", key = "vocksel/orion#2" } },
		}),
	})
	local fetched = collectPulls(doc, function(argv)
		local query = argv[#argv]

		if query:find("pullRequests(first:", 1, true) then
			return testing.result(false, "", "gh: HTTP 401")
		elseif query:find("viewer { login }", 1, true) then
			return testing.result(true, [[{"data":{"viewer":{"login":"vocksel"}}}]])
		end

		return testing.result(true, [[{"data":{"p1":{"pullRequest":{"number":2,"state":"OPEN","url":"u2"}}}}]])
	end, false)

	assert.eq(fetched.viewer, "vocksel")
	assert.eq(#fetched.authored, 0)
	assert.eq(#fetched.failures, 1)
	assert.strContains(fetched.failures[1], "your open pull requests")
	assert.neq(fetched.pulls["vocksel/orion#2"], nil)
end)
