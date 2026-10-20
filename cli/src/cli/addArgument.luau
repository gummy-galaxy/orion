local cli = require("@batteries/cli")

local cliTypes = require("@root/cli/types")
local definitions = require("@root/cli/definitions")

type ValueType = cliTypes.ValueType

export type Options = {
	help: string?,
	aliases: { string }?,
	required: boolean?,
	-- What the value is. Defaults to text, or to a list for a variadic.
	type: ValueType?,
	values: { string }?,
	minimum: number?,
	mcp: cliTypes.ArgumentMcp?,
}

-- Adds an argument along with what its value is, which the parser has no room for. MCP schemas and
-- orion help --all --json read it back through describeCommands.
local function addArgument(
	parser: cli.Parser,
	name: string,
	kind: "positional" | "option" | "variadic",
	options: Options
)
	parser:add(name, kind, { help = options.help, aliases = options.aliases, required = options.required })

	local details = definitions.arguments[parser] or {}
	definitions.arguments[parser] = details
	details[name] = {
		type = options.type or if kind == "variadic" then "list" else "text",
		values = options.values,
		minimum = options.minimum,
		mcp = options.mcp,
	}
end

return addArgument
