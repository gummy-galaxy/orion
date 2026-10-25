local aliasTypes = require("@root/aliases/types")
local describeCommands = require("@root/cli/describeCommands")

type Alias = aliasTypes.Alias
type CommandDescription = describeCommands.CommandDescription

local function findCommand(root: CommandDescription, path: string): CommandDescription?
	local name = `orion {path}`

	if root.name == name then
		return root
	end

	for _, command in root.commands do
		local found = findCommand(command, path)

		if found then
			return found
		end
	end

	return nil
end

local function takesOption(command: CommandDescription, name: string): boolean
	for _, argument in command.arguments do
		if argument.name == name or table.find(argument.aliases, name) then
			return true
		end
	end

	return false
end

local function describeAlias(alias: Alias): string
	if alias.kind == "option" then
		return `the alias --{alias.from} on orion {alias.command or "?"}`
	end

	return `the alias orion {alias.from}`
end

local function checkCommand(root: CommandDescription, alias: Alias, problems: { string })
	local label = describeAlias(alias)

	if findCommand(root, alias.to) == nil then
		table.insert(problems, `{label} points at orion {alias.to}, which doesn't exist`)
	end

	if findCommand(root, alias.from) then
		table.insert(problems, `{label} hides the live command orion {alias.from}`)
	end
end

local function checkOption(root: CommandDescription, alias: Alias, problems: { string })
	local label = describeAlias(alias)
	local command = if alias.command then findCommand(root, alias.command) else nil

	if command == nil then
		table.insert(problems, `{label} names a command that doesn't exist`)
		return
	end

	if not takesOption(command, alias.to) then
		table.insert(problems, `{label} points at --{alias.to}, which orion {alias.command} doesn't take`)
	end

	if takesOption(command, alias.from) then
		table.insert(problems, `{label} hides the live option --{alias.from}`)
	end
end

-- Lists what's wrong with the alias entries against the command table: a target that doesn't exist, an old name
-- that hides a live one, a repeated old name, or a missing date or pull request.
local function checkAliases(root: CommandDescription, aliases: { Alias }): { string }
	local problems: { string } = {}
	local seen: { [string]: boolean } = {}

	for _, alias in aliases do
		local label = describeAlias(alias)
		local key = `{alias.kind} {alias.command or ""} {alias.from}`

		if seen[key] then
			table.insert(problems, `{label} is listed twice`)
		end

		seen[key] = true

		if not alias.added:match("^%d%d%d%d%-%d%d%-%d%d$") then
			table.insert(problems, `{label} needs the date it was added, as YYYY-MM-DD`)
		end

		if not (alias.pr > 0 and alias.pr == math.floor(alias.pr)) then
			table.insert(problems, `{label} needs the pull request that added it`)
		end

		if alias.kind == "command" then
			checkCommand(root, alias, problems)
		else
			checkOption(root, alias, problems)
		end
	end

	return problems
end

return checkAliases
