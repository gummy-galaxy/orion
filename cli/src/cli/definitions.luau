local cli = require("@batteries/cli")

local cliTypes = require("@root/cli/types")

type ArgumentDetails = cliTypes.ArgumentDetails
type ToolDeclaration = cliTypes.ToolDeclaration

-- What a parser can't hold itself: each argument's value type, and each command's MCP tool. addArgument and
-- defineSubcommands fill them in as commands are defined, and describeCommands reads them back. Parsers are weak
-- keys, so each call's parsers are collected with it.
local arguments: { [cli.Parser]: { [string]: ArgumentDetails } } = setmetatable({}, { __mode = "k" }) :: any
local tools: { [cli.Parser]: ToolDeclaration } = setmetatable({}, { __mode = "k" }) :: any

return table.freeze({
	arguments = arguments,
	tools = tools,
})
