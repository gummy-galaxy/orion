local test = require("@std/test")

local getArgumentLabel = require("@root/cli/getArgumentLabel")

test.case("getArgumentLabel writes each kind of argument as it appears on the command line", function(assert)
	local function label(kind, required: boolean): string
		return getArgumentLabel({ name = "id", kind = kind, required = required, aliases = {} })
	end

	assert.eq(label("positional", true), "<id>")
	assert.eq(label("positional", false), "[id]")
	assert.eq(label("variadic", true), "<id...>")
	assert.eq(label("variadic", false), "[id...]")
	assert.eq(label("option", false), "--id <value>")
	assert.eq(label("flag", false), "--id")
end)
