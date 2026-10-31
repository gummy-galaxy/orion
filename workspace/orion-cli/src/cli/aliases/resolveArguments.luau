local cli = require("@batteries/cli")

local aliasTypes = require("@root/cli/aliases/types")

type Alias = aliasTypes.Alias

type Rewrite = {
	args: { string },
	notice: string,
}

-- Enough to follow a renamed group and then a renamed command under it, and few
-- enough that a loop fails fast.
local MAX_REWRITES = 10

-- The kind of the argument a parser knows by this name or alias, if any.
local function findArgumentKind(parser: cli.Parser, name: string): string?
	for _, argument in parser.arguments do
		if argument.name == name or table.find(argument.options.aliases or {}, name) then
			return argument.kind
		end
	end

	return nil
end

local function findSubcommand(parser: cli.Parser, name: string): cli.Parser?
	for _, command in parser.commands do
		if command.name == name then
			return command.parser
		end
	end

	return nil
end

local function formatNotice(old: string, new: string): string
	return `Notice: {old} is now {new}, and the old name stops working in the next release.`
end

-- Whether a command alias's old path continues the path walked so far with the
-- arguments from index on.
local function continuesPath(from: { string }, path: { string }, args: { string }, index: number): boolean
	if #from <= #path then
		return false
	end

	for position, word in path do
		if from[position] ~= word then
			return false
		end
	end

	for position = #path + 1, #from do
		if args[index + position - #path - 1] ~= from[position] then
			return false
		end
	end

	return true
end

-- Swaps an old command path for its new one. The old path's words may sit
-- between options, so they're taken out wherever they are and the new path goes
-- where the old one started.
local function replacePath(
	args: { string },
	positions: { number },
	index: number,
	alias: Alias,
	from: { string }
): Rewrite
	local removed: { [number]: boolean } = {}

	for _, position in positions do
		removed[position] = true
	end

	for position = index, index + #from - #positions - 1 do
		removed[position] = true
	end

	local start = positions[1] or index
	local rewritten: { string } = {}

	for position, arg in args do
		if position == start then
			for _, word in string.split(alias.to, " ") do
				table.insert(rewritten, word)
			end
		end

		if not removed[position] then
			table.insert(rewritten, arg)
		end
	end

	return { args = rewritten, notice = formatNotice(`orion {alias.from}`, `orion {alias.to}`) }
end

local function findOptionAlias(aliases: { Alias }, command: string, name: string): Alias?
	for _, alias in aliases do
		if alias.kind == "option" and alias.command == command and alias.from == name then
			return alias
		end
	end

	return nil
end

-- Walks the arguments as the parser would and rewrites the first old name it
-- meets, if any. orion help takes a command path as its topic, so the words
-- after it are walked from the root again.
local function findRewrite(args: { string }, root: cli.Parser, aliases: { Alias }): Rewrite?
	local current = root
	local path: { string } = {}
	local positions: { number } = {}
	local pathEnded = false
	local index = 0

	while index < #args do
		index += 1
		local arg = args[index]

		if arg == "--" then
			return nil
		elseif arg:sub(1, 2) == "--" then
			local name = arg:sub(3)
			local kind = findArgumentKind(current, name)

			if kind then
				if kind == "option" then
					index += 1
				end

				continue
			end

			local command = table.concat(path, " ")
			local alias = findOptionAlias(aliases, command, name)

			if alias then
				local rewritten = table.clone(args)
				rewritten[index] = `--{alias.to}`
				return { args = rewritten, notice = formatNotice(`--{name} on orion {command}`, `--{alias.to}`) }
			end

			continue
		elseif arg:sub(1, 1) == "-" then
			for position = 2, #arg do
				if findArgumentKind(current, arg:sub(position, position)) == "option" then
					index += 1
				end
			end

			continue
		elseif pathEnded then
			continue
		end

		local subcommand = findSubcommand(current, arg)

		if subcommand and #path == 0 and arg == "help" then
			continue
		elseif subcommand then
			current = subcommand
			table.insert(path, arg)
			table.insert(positions, index)
			continue
		end

		for _, alias in aliases do
			local from = string.split(alias.from, " ")

			if alias.kind == "command" and continuesPath(from, path, args, index) then
				return replacePath(args, positions, index, alias, from)
			end
		end

		pathEnded = true
	end

	return nil
end

-- Rewrites old command paths and options in a command line to their current
-- names, before the parser reads it. Returns the rewritten arguments and a
-- notice for each rename it made.
local function resolveArguments(args: { string }, root: cli.Parser, aliases: { Alias }): ({ string }, { string })
	local resolved = args
	local notices: { string } = {}

	for _ = 1, MAX_REWRITES do
		local rewrite = findRewrite(resolved, root, aliases)

		if rewrite == nil then
			return resolved, notices
		end

		resolved = rewrite.args
		table.insert(notices, rewrite.notice)
	end

	error(`aliases rename {table.concat(args, " ")} more than {MAX_REWRITES} times, so two of them may loop`)
end

return resolveArguments
