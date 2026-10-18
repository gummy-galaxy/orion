local cli = require("@batteries/cli")

local function getRequired(parser: cli.Parser, name: string): string
	return assert(parser:get(name), `missing <{name}>`)
end

return getRequired
