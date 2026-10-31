local test = require("@std/test")

local json = require("@std/json")
local queryAsync = require("@root/sources/github/api/queryAsync")
local testing = require("@root/testing")

test.case("queryAsync keeps usable GraphQL data from partial failures", function(assert)
	local data = queryAsync(function(argv)
		assert.eq(argv[3], "--hostname")
		assert.eq(argv[4], "github.example.com")
		return testing.result(false, [[{"data":{"viewer":{"login":"vocksel"}},"errors":[{"message":"partial"}]}]])
	end, "query { viewer { login } }", "github.example.com")
	local viewer = if data then json.asObject(data.viewer) else nil
	assert.eq(viewer and viewer.login, "vocksel")
end)

test.case("queryAsync raises GitHub's error when a query returns no data", function(assert)
	local succeeded, message = pcall(queryAsync, function()
		return testing.result(
			false,
			[[{"data":null,"errors":[{"message":"Something went wrong while executing your query. This may be the ]]
				.. [[result of a timeout"}]}]]
		)
	end, "query { viewer { login } }", nil)
	assert.eq(succeeded, false)
	assert.strContains(tostring(message), "timeout")
end)
