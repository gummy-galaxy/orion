local cli = require("@batteries/cli")
local test = require("@std/test")

local addFieldOptions = require("@root/cli/addFieldOptions")
local getItemFields = require("@root/cli/getItemFields")

local function parse(args: { string }): cli.Parser
	local parser = cli.parser()
	addFieldOptions(parser, true)
	parser:parse(args)
	return parser
end

test.case("getItemFields reads a pull request number with or without a hash", function(assert)
	assert.eq(getItemFields(parse({ "--pr", "#12" })).pr, 12)
	assert.eq(getItemFields(parse({ "--pr", "12", "--status", "active" })).status, "active")
end)

test.case("getItemFields rejects a pull request that isn't a number", function(assert)
	assert.throwsWith("pr must be a number", function()
		getItemFields(parse({ "--pr", "twelve" }))
	end)
end)
