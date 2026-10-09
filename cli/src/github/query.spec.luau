local test = require("@std/test")

local json = require("@std/json")
local query = require("@root/github/query")
local testing = require("@root/testing")

test.case("query keeps usable GraphQL data from partial failures", function(assert)
	local data = query(function(argv)
		assert.eq(argv[3], "--hostname")
		assert.eq(argv[4], "github.example.com")
		return testing.result(false, [[{"data":{"viewer":{"login":"vocksel"}},"errors":[{"message":"partial"}]}]])
	end, "query { viewer { login } }", "github.example.com")
	local viewer = if data then json.asObject(data.viewer) else nil
	assert.eq(viewer and viewer.login, "vocksel")
end)
