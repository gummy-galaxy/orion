--[[
	Warns when a file's top-level requires aren't in two blocks: third-party
	packages, such as `@std` or `@batteries`, in one block, then Orion's own
	modules, such as `@root`, in another, with a blank line between. That
	way a reader can tell at a glance what comes from outside the repository.
	StyLua's `sort_requires` sorts the requires within each
	blank-line-separated block, so this rule only decides the blocks.

	The suggested fix regroups the requires, so `lute lint --auto-fix` applies
	it. It's left out when the rewrite would drop or break something: a
	comment or other code among the requires or on their lines, or a package
	whose type annotation names one of Orion's modules required above it.
]]
local lintTypes = require("@std/commands/lint/types")
local path = require("@std/path")
local printer = require("@std/syntax/printer")
local syntax = require("@std/syntax")

local name = "require_groups"

-- The aliases for Orion's own code, from the `.config.luau` files at the
-- repository root and in `workspace/orion-cli`, plus Luau's `@self` for a
-- folder's own modules. Every other alias is a package, including `@pkg`
-- and `@batteries`, which point at packages Loom installs under
-- `workspace/orion-cli/packages`. A path with no alias, like `./types`, is
-- Orion's own too. The list is copied here because Luau won't load a
-- `.config.luau` file through `require`, so update it when an alias changes.
local OWN_ALIASES = {
	repo = true,
	repository = true,
	root = true,
	self = true,
	workspace = true,
}

type Require = {
	statement: syntax.CstStat,
	isOwn: boolean,
	-- The local the require is assigned to.
	variable: string,
}

-- Returns the path a statement like `local x = require("@std/x")` requires,
-- or nil when the statement is something else. A type cast after the call
-- still counts.
local function getRequirePath(statement: syntax.CstStat): string?
	if statement.tag ~= "local" then
		return nil
	end

	local values = (statement :: syntax.CstStatLocal).values

	if #values ~= 1 then
		return nil
	end

	local value = values[1]

	if value.tag == "cast" then
		value = (value :: syntax.CstExprTypeAssertion).operand
	end

	if value.tag ~= "call" then
		return nil
	end

	local call = value :: syntax.CstExprCall

	if call.func.tag ~= "global" or (call.func :: syntax.CstExprGlobal).name.text ~= "require" then
		return nil
	end

	if #call.arguments ~= 1 or call.arguments[1].tag ~= "string" then
		return nil
	end

	return (call.arguments[1] :: syntax.CstExprConstantString).value.text
end

local function isOwnPath(requirePath: string): boolean
	local alias = requirePath:match("^@([^/]+)")
	return alias == nil or OWN_ALIASES[alias] == true
end

local function isBlank(sourceLines: { string }, line: number): boolean
	return (sourceLines[line] or ""):match("^%s*$") ~= nil
end

-- Whether a blank line separates two requires, which starts a new block.
local function isBlankBetween(sourceLines: { string }, before: Require, after: Require): boolean
	for line = before.statement.location.endLine + 1, after.statement.location.beginLine - 1 do
		if isBlank(sourceLines, line) then
			return true
		end
	end

	return false
end

-- A file breaks the rule when a package comes after any of Orion's modules,
-- or when a blank line falls anywhere but between the two groups.
local function isMisplaced(sourceLines: { string }, requires: { Require }): boolean
	local seenOwn = false

	for index, current in requires do
		if seenOwn and not current.isOwn then
			return true
		end

		local previous = requires[index - 1]

		if previous and (previous.isOwn == current.isOwn) == isBlankBetween(sourceLines, previous, current) then
			return true
		end

		seenOwn = seenOwn or current.isOwn
	end

	return false
end

-- Returns the statement's text when it has its lines to itself, or nil when
-- something else, such as a trailing comment, shares them.
local function getOwnText(sourceLines: { string }, statement: syntax.CstStat): string?
	local location = statement.location
	local lines = { table.unpack(sourceLines, location.beginLine, location.endLine) }

	if location.beginColumn ~= 1 or lines[#lines]:sub(location.endColumn):match("%S") then
		return nil
	end

	lines[#lines] = lines[#lines]:sub(1, location.endColumn - 1)

	return table.concat(lines, "\n")
end

-- Whether a package's statement, such as `local x = require("@pkg/x") ::
-- types.X`, names one of Orion's modules required above it. Moving the
-- package above that module would use the name before it's defined.
local function usesEarlierModule(requires: { Require }, texts: { [Require]: string }, index: number): boolean
	local text = texts[requires[index]]:gsub("require%b()", "")

	for earlier = 1, index - 1 do
		local module = requires[earlier]

		if module.isOwn and text:find(`%f[%w_]{module.variable}%f[^%w_]`) then
			return true
		end
	end

	return false
end

-- Rebuilds the requires as two blocks, packages first, or returns nil when
-- the rewrite would drop or break something. Each block keeps its requires
-- in their order.
local function regroup(sourceLines: { string }, requires: { Require }): string?
	local texts: { [Require]: string } = {}

	for index, current in requires do
		local text = getOwnText(sourceLines, current.statement)

		if text == nil then
			return nil
		end

		texts[current] = text

		local previous = requires[index - 1]

		if previous then
			for line = previous.statement.location.endLine + 1, current.statement.location.beginLine - 1 do
				if not isBlank(sourceLines, line) then
					return nil
				end
			end
		end
	end

	local packages: { string } = {}
	local modules: { string } = {}

	for index, current in requires do
		if current.isOwn then
			table.insert(modules, texts[current])
		elseif usesEarlierModule(requires, texts, index) then
			return nil
		else
			table.insert(packages, texts[current])
		end
	end

	local blocks: { string } = {}

	for _, block in { packages, modules } do
		if #block > 0 then
			table.insert(blocks, table.concat(block, "\n"))
		end
	end

	return table.concat(blocks, "\n\n")
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { lintTypes.LintViolation }
	local requires: { Require } = {}
	local firstIndex = 0
	local lastIndex = 0

	for index, statement in cst.statements do
		local requirePath = getRequirePath(statement)

		if requirePath then
			table.insert(requires, {
				statement = statement,
				isOwn = isOwnPath(requirePath),
				variable = (statement :: syntax.CstStatLocal).variables[1].name.text,
			})
			firstIndex = if firstIndex == 0 then index else firstIndex
			lastIndex = index
		end
	end

	if #requires == 0 then
		return {}
	end

	-- A rule gets only the parsed tree, not the file's text. Printing the tree
	-- gives back the source as written, quotes included, line for line.
	local sourceLines = printer.printNode(cst):split("\n")

	if not isMisplaced(sourceLines, requires) then
		return {}
	end

	local first = requires[1].statement.location
	local last = requires[#requires].statement.location
	local location = syntax.span.create({
		beginLine = first.beginLine,
		beginColumn = first.beginColumn,
		endLine = last.endLine,
		endColumn = last.endColumn,
	})

	-- The fix replaces everything from the first require to the last, so
	-- other statements between them would be lost.
	local isContiguous = lastIndex - firstIndex + 1 == #requires
	local fix = if isContiguous then regroup(sourceLines, requires) else nil

	local violation: lintTypes.LintViolation = {
		lintname = name,
		location = location,
		message = "put third-party package requires in one block above one block of Orion's own modules",
		severity = "warning",
		sourcepath = sourcepath,
		suggestedfix = if fix then { location = location, fix = fix } else nil,
	}

	return { violation }
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
