local cli = require("@batteries/cli")
local test = require("@std/test")

local addArgument = require("@root/cli/addArgument")
local buildTools = require("@root/cli/mcp/catalog/buildTools")
local cliTypes = require("@root/cli/types")
local definitions = require("@root/cli/definitions")
local describeCommands = require("@root/cli/describeCommands")

type Annotations = cliTypes.Annotations

-- A small command table: card add declares its tool, card path skips MCP, and
-- card show declares nothing.
local function createRoot(): (cli.Parser, cli.Parser)
	local root = cli.parser()
	local card = root:subcommand("card", { help = "Cards" })

	local add = card:subcommand("add", { help = "Add a card" })
	definitions.tools[add] = { annotations = { openWorldHint = true } }
	addArgument(add, "label", "variadic", { help = "What the work is", type = "words" })
	addArgument(add, "if-revision", "option", { help = "Revision", type = "integer", minimum = 0 })
	add:add("dry-run", "flag", { help = "Preview" })
	add:add("json", "flag", { help = "Print JSON" })

	local path = card:subcommand("path", { help = "Print a path" })
	definitions.tools[path] = { skip = "reports a local folder" }

	return root, card:subcommand("show", { help = "Show a card" })
end

test.case("buildTools names each tool after its command and takes a field for each option", function(assert)
	local root, show = createRoot()
	definitions.tools[show] = { omit = { { option = "canvas", reason = "shows the card everywhere" } } }

	local tools = buildTools(describeCommands(root, "orion"))

	assert.eq(#tools, 2)
	assert.eq(tools[1].name, "orion_card_add")
	assert.eq(tools[1].description, "Add a card")
	assert.eq(tools[1].command, { "card", "add" })
	assert.eq(tools[1].json, true)
	assert.eq((tools[1].annotations :: Annotations).openWorldHint, true)

	local names: { string } = {}

	for _, field in tools[1].fields do
		table.insert(names, field.name)
	end

	assert.eq(names, { "label", "canvas", "ifRevision", "dryRun" })
	assert.eq(tools[1].fields[1].required, true)
	assert.eq(tools[1].fields[3].minimum, 0)
	assert.eq(tools[1].fields[3].argument, "if-revision")
	assert.eq(tools[2].name, "orion_card_show")
	assert.eq(#tools[2].fields, 0)
	assert.eq(tools[2].json, false)
end)

test.case("buildTools fails for a command with no declaration and for an omission it doesn't take", function(assert)
	local root, show = createRoot()
	assert.throwsWith("orion card show declares no MCP tool, or why it has none", function()
		buildTools(describeCommands(root, "orion"))
	end)

	definitions.tools[show] = { omit = { { option = "stdin", reason = "reads stdin" } } }
	assert.throwsWith("orion card show omits --stdin, which it doesn't take", function()
		buildTools(describeCommands(root, "orion"))
	end)
end)

test.case("buildTools fails for a tool that would take a program to run", function(assert)
	local root, show = createRoot()
	definitions.tools[show] = {}
	addArgument(show, "command", "option", { help = "Command to run", type = "command" })
	assert.throwsWith("orion card show takes --command, which runs a program, so its tool must omit it", function()
		buildTools(describeCommands(root, "orion"))
	end)

	definitions.tools[show] = { omit = { { option = "command", reason = "runs a program" } } }
	assert.eq(#buildTools(describeCommands(root, "orion")), 2)
end)
