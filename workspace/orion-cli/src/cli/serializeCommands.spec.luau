local json = require("@std/json")
local test = require("@std/test")

local serializeCommands = require("@root/cli/serializeCommands")

test.case("serializeCommands keeps empty lists as arrays, nests subcommands, and reports value types", function(assert)
	local text = json.serialize(serializeCommands({
		name = "orion",
		help = "Summary",
		usage = "orion <command> [options]",
		arguments = {},
		commands = {
			{
				name = "orion next",
				usage = "orion next [options]",
				arguments = {
					{
						name = "json",
						kind = "flag",
						type = "boolean",
						help = "Print JSON",
						required = false,
						aliases = {},
					},
					{
						name = "status",
						kind = "option",
						type = "enum",
						values = { "todo", "done" },
						required = false,
						aliases = {},
					},
				},
				commands = {},
			},
		},
	}))

	local parsed = json.asObject(json.deserialize(text) :: json.Value)
	local commands = parsed and json.asArray(parsed.commands)
	local next = commands and json.asObject(commands[1])
	local arguments = next and json.asArray(next.arguments)
	local flag = arguments and json.asObject(arguments[1])
	local option = arguments and json.asObject(arguments[2])

	assert.eq(parsed and parsed.help, "Summary")
	assert.strContains(text, '"arguments":[]')
	assert.eq(next and next.name, "orion next")
	assert.eq(next and next.help, nil)
	assert.eq(flag and flag.kind, "flag")
	assert.eq(flag and flag.required, false)
	assert.strContains(text, '"aliases":[]')
	assert.eq(flag and flag.type, "boolean")
	assert.eq(flag and flag.values, nil)
	assert.eq(option and option.type, "enum")
	assert.strContains(text, '"values":["todo","done"]')
end)
