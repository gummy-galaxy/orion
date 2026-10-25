local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local checkAliases = require("@root/aliases/checkAliases")
local cli = require("@root/cli")
local entries = require("@root/aliases/entries")

test.case("every shipped alias points at a live name and hides none", function(assert)
	assert.eq(table.concat(checkAliases(cli.describe(), entries), "\n"), "")
end)

test.case("every shipped alias has its row in the README", function(assert)
	local readme = fs.readFileToString(tostring(path.join("src", "aliases", "README.md")))

	for _, alias in entries do
		local name = if alias.kind == "option" then `--{alias.from}` else `orion {alias.from}`
		local row = `| \`{name}\``
		assert.strContains(readme, row)
		assert.strContains(readme, `/pull/{alias.pr})`)
	end
end)
