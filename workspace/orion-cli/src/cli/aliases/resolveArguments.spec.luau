local cli = require("@batteries/cli")
local test = require("@std/test")

local aliasTypes = require("@root/cli/aliases/types")
local resolveArguments = require("@root/cli/aliases/resolveArguments")

type Alias = aliasTypes.Alias

-- Sample entries only: the shipped list starts each release empty.
local ALIASES: { Alias } = {
	{ kind = "command", from = "card new", to = "card add", added = "2026-10-19", pr = 1 },
	{ kind = "command", from = "workspace", to = "canvas", added = "2026-10-19", pr = 1 },
	{ kind = "option", command = "card add", from = "folder", to = "group", added = "2026-10-19", pr = 1 },
}

-- A small command table shaped like Orion's: every command takes --help and
-- --canvas.
local function createRoot(): cli.Parser
	local root = cli.parser()
	root:add("help", "flag", { aliases = { "h" } })
	root:add("canvas", "option", {})

	local function addCommand(parent: cli.Parser, name: string): cli.Parser
		local parser = parent:subcommand(name, {})
		parser:add("help", "flag", { aliases = { "h" } })
		parser:add("canvas", "option", {})
		return parser
	end

	local card = addCommand(root, "card")
	local add = addCommand(card, "add")
	add:add("label", "variadic", {})
	add:add("group", "option", { aliases = { "g" } })
	add:add("json", "flag", {})
	addCommand(card, "list")
	addCommand(addCommand(root, "canvas"), "list")

	local help = addCommand(root, "help")
	help:add("command", "variadic", {})
	help:add("all", "flag", {})

	return root
end

local function resolve(args: { string }, aliases: { Alias }?): ({ string }, { string })
	return resolveArguments(args, createRoot(), aliases or ALIASES)
end

test.case("an old command path becomes the new one, with a notice", function(assert)
	local args, notices = resolve({ "card", "new", "Write", "notes", "--group", "ws", "--json" })

	assert.eq(args, { "card", "add", "Write", "notes", "--group", "ws", "--json" })
	assert.eq(
		notices,
		{ "Notice: orion card new is now orion card add, and the old name stops working in the next release." }
	)
end)

test.case("a renamed group covers the commands under it", function(assert)
	local args, notices = resolve({ "workspace", "list" })

	assert.eq(args, { "canvas", "list" })
	assert.eq(#notices, 1)
end)

test.case("an option's value and options between command words are left alone", function(assert)
	assert.eq((resolve({ "--canvas", "new", "card", "new", "x" })), { "--canvas", "new", "card", "add", "x" })
	assert.eq((resolve({ "card", "--canvas", "x", "new", "Label" })), { "card", "add", "--canvas", "x", "Label" })
	assert.eq((resolve({ "card", "add", "--group", "--folder" })), { "card", "add", "--group", "--folder" })
	assert.eq((resolve({ "card", "add", "-g", "--folder" })), { "card", "add", "-g", "--folder" })
end)

test.case("an old option becomes the new one on the command that takes it", function(assert)
	local args, notices = resolve({ "card", "add", "Label", "--folder", "ws" })

	assert.eq(args, { "card", "add", "Label", "--group", "ws" })
	assert.eq(
		notices,
		{ "Notice: --folder on orion card add is now --group, and the old name stops working in the next release." }
	)
	assert.eq((resolve({ "card", "list", "--folder", "ws" })), { "card", "list", "--folder", "ws" })
end)

test.case("an old command and an old option on it both resolve", function(assert)
	local args, notices = resolve({ "card", "new", "Label", "--folder", "ws" })

	assert.eq(args, { "card", "add", "Label", "--group", "ws" })
	assert.eq(#notices, 2)
end)

test.case("help resolves an old command path given as its topic", function(assert)
	assert.eq((resolve({ "help", "card", "new" })), { "help", "card", "add" })
end)

test.case("words that only look like old names stay as they are", function(assert)
	local unchanged = {
		{ "card", "add", "new" },
		{ "card", "add", "Label", "--", "--folder" },
		{ "new" },
		{ "card", "bogus", "new" },
	}

	for _, args in unchanged do
		local resolved, notices = resolve(args)
		assert.eq(resolved, args)
		assert.eq(#notices, 0)
	end
end)

test.case("aliases that rename each other fail instead of looping", function(assert)
	local looping: { Alias } = {
		{ kind = "command", from = "card old", to = "card older", added = "2026-10-19", pr = 1 },
		{ kind = "command", from = "card older", to = "card old", added = "2026-10-19", pr = 1 },
	}

	assert.throwsWith("may loop", function()
		resolve({ "card", "old" }, looping)
	end)
end)
