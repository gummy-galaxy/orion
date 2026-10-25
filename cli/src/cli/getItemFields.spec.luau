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

test.case("getItemFields reads the fields cards take", function(assert)
	local fields = getItemFields(parse({ "--repo", "vocksel/orion", "--status", "active" }))
	assert.eq(fields.repo, "vocksel/orion")
	assert.eq(fields.status, "active")
end)
