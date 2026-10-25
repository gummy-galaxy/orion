local test = require("@std/test")

local findRefreshSooner = require("@root/server/findRefreshSooner")
local testing = require("@root/testing")

test.case("the cards in view refresh sooner", function(assert)
	local doc = testing.createDoc({
		testing.task("api", "Land the API", "review"),
		testing.task("ship", "Ship", "todo"),
		testing.task("other", "Elsewhere", "todo"),
	}, { { "api", "ship" } })
	local sooner = findRefreshSooner(doc, { open = nil, selected = { "ship" } })

	assert.eq(sooner.ship, true)
	assert.eq(sooner.api, true)
	assert.eq(sooner.other, nil)
end)

test.case("nothing refreshes sooner while the app is closed", function(assert)
	local doc = testing.createDoc({ testing.task("api", "Land the API", "review") })

	assert.eq(next(findRefreshSooner(doc, nil)), nil)
end)
