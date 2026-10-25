local json = require("@std/json")
local test = require("@std/test")

local formatFailure = require("@root/cli/formatFailure")

test.case("a failure under --json prints the message as a JSON error", function(assert)
	local _, failure = pcall(error, 'no item or group with id "missing"')
	local value = json.asObject(json.deserialize(formatFailure({ "node", "show", "missing", "--json" }, failure)))
	local error = if value then json.asObject(value.error) else nil
	assert.eq(error and error.message, 'no item or group with id "missing"')
end)

test.case("a failure without --json prints an Error: line", function(assert)
	assert.eq(formatFailure({ "node", "show", "missing" }, "no such item"), "Error: no such item")
end)

test.case("--json after -- is passed along rather than asking for JSON", function(assert)
	assert.eq(formatFailure({ "apply", "--", "--json" }, "bad plan"), "Error: bad plan")
end)
