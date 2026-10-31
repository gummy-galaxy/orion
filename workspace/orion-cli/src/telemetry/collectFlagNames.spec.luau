local cli = require("@batteries/cli")
local test = require("@std/test")

local collectFlagNames = require("@root/telemetry/collectFlagNames")

test.case("only the names of flags and options given are collected, sorted", function(assert)
	local root = cli.parser()
	root:add("canvas", "option")
	local child = root:subcommand("set")
	child:add("id", "positional")
	child:add("json", "flag")
	child:add("note", "option")
	child:add("dry-run", "flag")

	root:parse({ "set", "--note", "--json-ish secret", "abc", "--json" })
	local _, selected = root:selected()

	assert.eq(collectFlagNames({ root, selected :: cli.Parser }), "--json,--note")
end)

test.case("a command given nothing has no flags", function(assert)
	local root = cli.parser()
	root:add("json", "flag")
	root:parse({})

	assert.eq(collectFlagNames({ root }), "")
end)
