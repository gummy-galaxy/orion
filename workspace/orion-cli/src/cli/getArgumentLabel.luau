local describeCommands = require("@root/cli/describeCommands")

type Argument = describeCommands.Argument

-- How an argument is written on the command line, such as `<id>`, `[ids...]`,
-- or `--group <value>`.
local function getArgumentLabel(argument: Argument): string
	if argument.kind == "positional" then
		return if argument.required then `<{argument.name}>` else `[{argument.name}]`
	elseif argument.kind == "variadic" then
		return if argument.required then `<{argument.name}...>` else `[{argument.name}...]`
	elseif argument.kind == "option" then
		return `--{argument.name} <value>`
	end

	return `--{argument.name}`
end

return getArgumentLabel
