local test = require("@std/test")

local collectPulls = require("@root/github/collectPulls")
local testing = require("@root/testing")

test.case("collect batches pull request lookups by host", function(assert)
	local doc = testing.createDoc({
		testing.task("public", "Public", "todo", nil, { repo = "flipbook", pr = 1 }),
		testing.task(
			"private",
			"Private",
			"todo",
			nil,
			{ repo = "Roblox/avatar", pr = 2, host = "github.example.com" }
		),
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
