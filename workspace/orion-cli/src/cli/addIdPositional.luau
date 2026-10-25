local cli = require("@batteries/cli")

local addArgument = require("@root/cli/addArgument")

-- An item or group named by its id or by a selector that must match exactly one.
local function addIdPositional(parser: cli.Parser, name: string)
	addArgument(parser, name, "positional", {
		help = 'Item or group id, or a selector such as label:"Extract slider", ref:jira:ABC-12, or pr:86',
		type = "id",
	})
end

return addIdPositional
