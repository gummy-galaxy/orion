local test = require("@std/test")

local describeCommands = require("@root/cli/describeCommands")
local formatAllHelp = require("@root/cli/formatAllHelp")

type Argument = describeCommands.Argument
type CommandDescription = describeCommands.CommandDescription

local function argument(
	name: string,
	kind: "positional" | "flag" | "option" | "variadic",
	help: string,
	required: boolean?
): Argument
	return { name = name, kind = kind, help = help, required = required == true, aliases = {} }
end

local ROOT: CommandDescription = {
	name = "orion",
	help = "Summary",
	usage = "orion <command> [options]",
	arguments = {},
	commands = {
		{
			name = "orion card",
			help = "Work items",
			usage = "orion card <command> [options]",
			arguments = {},
			commands = {
				{
					name = "orion card set",
					help = "Change an item",
					usage = "orion card set [id] [options]",
					arguments = {
						argument("id", "positional", "Item id"),
						argument("label", "option", "New label"),
						argument("json", "flag", "Print JSON"),
					},
					commands = {},
				},
			},
		},
		{
			name = "orion next",
			help = "List ready items",
			usage = "orion next [options]",
			arguments = { argument("json", "flag", "Print JSON") },
			commands = {},
		},
		{
			name = "orion log",
			help = "The log",
			usage = "orion log <command> [options]",
			arguments = {},
			commands = {
				{
					name = "orion log add",
					help = "Log what happened",
					usage = "orion log add <text...> [options]",
					arguments = { argument("text", "variadic", "What happened", true) },
					commands = {},
				},
			},
		},
	},
}

test.case("formatAllHelp groups commands by noun with aligned arguments", function(assert)
	local text = formatAllHelp(ROOT)

	assert.eq(
		text,
		table.concat({
			"card: Work items",
			"",
			"  orion card set [id]",
			"    Change an item",
			"    [id]             Item id",
			"    --label <value>  New label",
			"    --json           Print JSON",
			"",
			"next: List ready items",
			"",
			"  orion next",
			"    --json  Print JSON",
			"",
			"log: The log",
			"",
			"  orion log add <text...>",
			"    Log what happened",
			"    <text...>  What happened (required)",
		}, "\n")
	)
end)

test.case("formatAllHelp prints a command's details under its arguments", function(assert)
	local text = formatAllHelp(ROOT, { ["orion next"] = "First line\nSecond line" })

	assert.strContains(text, "    --json  Print JSON\n    First line\n    Second line")
end)

test.case("formatAllHelp shows argument aliases beside the label", function(assert)
	local text = formatAllHelp({
		name = "orion",
		usage = "orion",
		arguments = {},
		commands = {
			{
				name = "orion next",
				usage = "orion next",
				arguments = {
					{ name = "limit", kind = "option", help = "Most", required = false, aliases = { "n", "max" } },
				},
				commands = {},
			},
		},
	})

	assert.strContains(text, "--limit <value> (-n, --max)  Most")
end)
