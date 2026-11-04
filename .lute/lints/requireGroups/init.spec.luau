local syntax = require("@std/syntax")
local test = require("@std/test")

local requireGroups = require("@repository/.lute/lints/requireGroups")
local testing = require("@workspace/orion-cli/src/testing")

-- The fixes `lute lint --auto-fix` would make, in order.
local function getFixes(source: string): { string }
	local violations = requireGroups.lint(syntax.parse(source).root, nil, { globals = {}, options = {} })
	local fixes: { string } = {}

	for _, violation in violations do
		table.insert(fixes, if violation.suggestedfix then violation.suggestedfix.fix else "")
	end

	return fixes
end

test.case("requireGroups allows packages in a block above Orion's own modules", function(assert)
	local source = [[
local fs = require("@std/fs")
local cli = require("@batteries/cli")

local project = require("@repository/project")
local run = require("@root/common/process/run")
local docs = require("@self/docs")
]]

	assert.eq(testing.getLintedLines(requireGroups, source), {})
end)

test.case("requireGroups allows files with only one kind of require", function(assert)
	assert.eq(testing.getLintedLines(requireGroups, 'local fs = require("@std/fs")\n'), {})
	assert.eq(testing.getLintedLines(requireGroups, 'local run = require("@root/run")\n'), {})
	assert.eq(testing.getLintedLines(requireGroups, "local value = 1\n"), {})
end)

test.case("requireGroups moves packages above Orion's own modules in one block", function(assert)
	local source = [[
local project = require("@repository/project")
local fs = require("@std/fs")
local run = require("@workspace/orion-cli/src/common/process/run")
local path = require("@std/path")

return nil
]]

	assert.eq(testing.getLintedLines(requireGroups, source), { 1 })
	assert.eq(getFixes(source), {
		'local fs = require("@std/fs")\n'
			.. 'local path = require("@std/path")\n\n'
			.. 'local project = require("@repository/project")\n'
			.. 'local run = require("@workspace/orion-cli/src/common/process/run")',
	})
end)

test.case("requireGroups flags a package below Orion's own modules", function(assert)
	local source = [[
local fs = require("@std/fs")

local run = require("@root/run")

local cli = require("@batteries/cli")
]]

	assert.eq(testing.getLintedLines(requireGroups, source), { 1 })
	assert.eq(getFixes(source), {
		'local fs = require("@std/fs")\nlocal cli = require("@batteries/cli")\n\nlocal run = require("@root/run")',
	})
end)

test.case("requireGroups joins a group split across blocks", function(assert)
	local packages = [[
local test = require("@std/test")

local json = require("@std/json")

local parsePull = require("@root/sources/github/pulls/parsePull")
]]
	local modules = [[
local fs = require("@std/fs")

local run = require("@root/run")

local types = require("@root/types")
]]

	assert.eq(testing.getLintedLines(requireGroups, packages), { 1 })
	assert.eq(getFixes(packages), {
		'local test = require("@std/test")\n'
			.. 'local json = require("@std/json")\n\n'
			.. 'local parsePull = require("@root/sources/github/pulls/parsePull")',
	})
	assert.eq(getFixes(modules), {
		'local fs = require("@std/fs")\n\nlocal run = require("@root/run")\nlocal types = require("@root/types")',
	})
end)

test.case("requireGroups flags packages and modules in one block", function(assert)
	local source = [[
local fs = require("@std/fs")
local run = require("@root/run")
]]

	assert.eq(getFixes(source), { 'local fs = require("@std/fs")\n\nlocal run = require("@root/run")' })
end)

test.case("requireGroups counts relative paths and casts as requires", function(assert)
	local source = [[
local types = require("./types")
local lock = require("@std/json") :: any
]]

	assert.eq(getFixes(source), { 'local lock = require("@std/json") :: any\n\nlocal types = require("./types")' })
end)

test.case("requireGroups reports without a fix when moving the requires would drop or break code", function(assert)
	local commented = [[
local run = require("@root/run")
-- Formats paths.
local path = require("@std/path")
]]
	local interleaved = [[
local run = require("@root/run")
local name = "x"
local path = require("@std/path")
]]
	local typed = [[
local types = require("@root/types")
local client = require("@pkg/client") :: types.Client
]]
	local trailing = [[
local run = require("@root/run") -- Runs commands.
local path = require("@std/path")
]]

	assert.eq(getFixes(commented), { "" })
	assert.eq(getFixes(typed), { "" })
	assert.eq(getFixes(interleaved), { "" })
	assert.eq(getFixes(trailing), { "" })
end)

test.case("requireGroups skips requires inside functions", function(assert)
	local source = [[
local run = require("@root/run")

local function read()
	local json = require("@std/json")
	return json
end
]]

	assert.eq(testing.getLintedLines(requireGroups, source), {})
end)
