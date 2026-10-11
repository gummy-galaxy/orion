local test = require("@std/test")

local createSource = require("@root/adapters/hop/createSource")

test.case("hop adapter defaults to hop and validates executable", function(assert)
	assert.eq(createSource({}).command, { "hop" })
	assert.eq(createSource({ command = { '["/usr/local/bin/hop"]' } }).command, { "/usr/local/bin/hop" })
	assert.throws(function()
		createSource({ command = { '["hop","--token"]' } })
	end)
	assert.throws(function()
		createSource({ browse = { "https://example.com" } })
	end)
end)
