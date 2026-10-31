local cli = require("@batteries/cli")
local test = require("@std/test")

local aliasTypes = require("@root/cli/aliases/types")
local checkAliases = require("@root/cli/aliases/checkAliases")
local describeCommands = require("@root/cli/describeCommands")

type Alias = aliasTypes.Alias

-- card add, with --group, and card list.
local function describeRoot(): describeCommands.CommandDescription
	local root = cli.parser()
	local card = root:subcommand("card", {})
	local add = card:subcommand("add", {})
	add:add("group", "option", { aliases = { "g" } })
	card:subcommand("list", {})
	return describeCommands(root, "orion")
end

local function check(alias: Alias): string
	return table.concat(checkAliases(describeRoot(), { alias }), "\n")
end

test.case("aliases to commands and options that exist pass", function(assert)
	local problems = checkAliases(describeRoot(), {
		{ kind = "command", from = "card new", to = "card add", added = "2026-10-19", pr = 1 },
		{ kind = "command", from = "cards", to = "card", added = "2026-10-19", pr = 1 },
		{ kind = "option", command = "card add", from = "folder", to = "group", added = "2026-10-19", pr = 1 },
	})

	assert.eq(problems, {})
end)

test.case("an alias must point at a command or option that exists", function(assert)
	assert.strContains(
		check({ kind = "command", from = "card new", to = "card create", added = "2026-10-19", pr = 1 }),
		"points at orion card create, which doesn't exist"
	)
	assert.strContains(
		check({ kind = "option", command = "card add", from = "folder", to = "parent", added = "2026-10-19", pr = 1 }),
		"points at --parent, which orion card add doesn't take"
	)
	assert.strContains(
		check({ kind = "option", command = "card make", from = "folder", to = "group", added = "2026-10-19", pr = 1 }),
		"names a command that doesn't exist"
	)
end)

test.case("an alias can't hide a live command or option", function(assert)
	assert.strContains(
		check({ kind = "command", from = "card list", to = "card add", added = "2026-10-19", pr = 1 }),
		"hides the live command orion card list"
	)
	assert.strContains(
		check({ kind = "option", command = "card add", from = "g", to = "group", added = "2026-10-19", pr = 1 }),
		"hides the live option --g"
	)
end)

test.case("an alias needs its date and pull request, and is listed once", function(assert)
	assert.strContains(
		check({ kind = "command", from = "card new", to = "card add", added = "", pr = 1 }),
		"needs the date it was added"
	)
	assert.strContains(
		check({ kind = "command", from = "card new", to = "card add", added = "2026-10-19", pr = 0 }),
		"needs the pull request that added it"
	)

	local alias: Alias = { kind = "command", from = "card new", to = "card add", added = "2026-10-19", pr = 1 }
	assert.strContains(table.concat(checkAliases(describeRoot(), { alias, alias }), "\n"), "is listed twice")
end)
