local cli = require("@batteries/cli")
local test = require("@std/test")

local describeCommands = require("@root/cli/describeCommands")

test.case("describeCommands walks nested commands and leaves out shared and hidden arguments", function(assert)
	local root = cli.parser()
	root:add("help", "flag", { help = "Show this help" })
	root:add("workspace", "option", { help = "Use this workspace" })

	local workspace = root:subcommand("workspace", { help = "Manage workspaces" })
	local create = workspace:subcommand("create", { help = "Create a workspace" })
	create:add("name", "positional", { help = "Workspace name", required = true })
	create:add("label", "option", { help = "Display label" })
	create:add("internal", "flag", { hidden = true })
	root:subcommand("secret", { hidden = true })

	local described = describeCommands(root, "orion", "Summary")

	assert.eq(described.help, "Summary")
	assert.eq(#described.arguments, 0)
	assert.eq(#described.commands, 1)

	local created = described.commands[1].commands[1]

	assert.eq(created.name, "orion workspace create")
	assert.eq(created.usage, "orion workspace create <name> [options]")
	assert.eq(#created.arguments, 2)
	assert.eq(created.arguments[1].required, true)
	assert.eq(created.arguments[2].name, "label")
end)
