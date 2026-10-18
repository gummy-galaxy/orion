local cli = require("@batteries/cli")

-- An item or group named by its id or by a selector that must match exactly one.
local function addIdPositional(parser: cli.Parser, name: string)
	parser:add(
		name,
		"positional",
		{ help = 'Item or group id, or a selector such as label:"Extract slider", ref:jira:ABC-12, or pr:86' }
	)
end

return addIdPositional
