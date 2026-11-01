local cli = require("@batteries/cli")

-- The flags and options given to a command, from every parser on its path, as
-- `--name`s sorted and joined with commas, such as `--json,--where`. Only the
-- names the parser defines are read, so a value or positional argument never
-- ends up here, even one that looks like a flag.
local function collectTelemetryFlagNames(parsers: { cli.Parser }): string
	local seen: { [string]: boolean } = {}
	local names: { string } = {}

	for _, parser in parsers do
		for _, argument in parser.arguments do
			local isGiven = if argument.kind == "flag"
				then parser:has(argument.name)
				elseif argument.kind == "option" then parser:get(argument.name) ~= nil
				else false

			if isGiven and not seen[argument.name] then
				seen[argument.name] = true
				table.insert(names, `--{argument.name}`)
			end
		end
	end

	table.sort(names)

	return table.concat(names, ",")
end

return collectTelemetryFlagNames
