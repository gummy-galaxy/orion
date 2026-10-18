local json = require("@std/json")
local test = require("@std/test")

local serializeCommands = require("@root/cli/serializeCommands")

test.case("serializeCommands keeps empty lists as arrays and nests subcommands", function(assert)
	local text = json.serialize(serializeCommands({
		name = "orion",
		help = "Summary",
		usage = "orion <command> [options]",
		arguments = {},
		commands = {
			{
				name = "orion next",
				usage = "orion next [options]",
				arguments = { { name = "json", kind = "flag", help = "Print JSON", required = false, aliases = {} } },
				commands = {},
			},
		},
	}))

	local parsed = json.asObject(json.deserialize(text) :: json.Value)
	local commands = parsed and json.asArray(parsed.commands)
	local next = commands and json.asObject(commands[1])
	local arguments = next and json.asArray(next.arguments)
	local flag = arguments and json.asObject(arguments[1])

	assert.eq(parsed and parsed.help, "Summary")
	assert.strContains(text, '"arguments":[]')
	assert.eq(next and next.name, "orion next")
	assert.eq(next and next.help, nil)
	assert.eq(flag and flag.kind, "flag")
	assert.eq(flag and flag.required, false)
	assert.strContains(text, '"aliases":[]')
end)
