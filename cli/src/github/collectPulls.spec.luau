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

test.case("collect asks for the jobs of failing pull requests and leaves optional failures out", function(assert)
	local doc = testing.createDoc({
		testing.task("failing", "Failing", "review", nil, {
			repo = "vocksel/orion",
			refs = { { source = "github", kind = "pull", key = "vocksel/orion#341" } },
		}),
	})
	local jobQueries = 0
	local fetched = collectPulls(doc, function(argv)
		local query = argv[#argv]

		if query:find("pullRequests(first:", 1, true) then
			return testing.result(true, [[{"data":{"viewer":{"login":"vocksel","pullRequests":{"nodes":[]}}}}]])
		elseif query:find("isRequired", 1, true) then
			jobQueries += 1
			return testing.result(
				true,
				[[{"data":{"c1":{"pullRequest":{"commits":{"nodes":[{"commit":{"statusCheckRollup":{"contexts":{"nodes":[{"__typename":"CheckRun","name":"docs","conclusion":"FAILURE","isRequired":false},{"__typename":"CheckRun","name":"test","conclusion":"SUCCESS","isRequired":true}]}}}}]}}}}}]]
			)
		end

		return testing.result(
			true,
			[[{"data":{"p1":{"pullRequest":{"number":341,"title":"t","url":"u","state":"OPEN","isDraft":true,"author":{"login":"vocksel"},"updatedAt":"now","additions":1,"deletions":1,"reviewRequests":{"totalCount":0},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"FAILURE","contexts":{"checkRunCountsByState":[{"state":"FAILURE","count":1},{"state":"SUCCESS","count":1}]}}}}]}}}}}]]
		)
	end, false)
	local pull = fetched.pulls["vocksel/orion#341"]

	assert.eq(jobQueries, 1)
	assert.eq(pull and pull.checks, "SUCCESS")
	assert.eq(pull and pull.failedChecks and pull.failedChecks[1].optional, true)
end)
