--[[
	Warns when a local, parameter, or loop variable reuses the name of one already in scope, so the outer one can't be
	reached from inside. Names that start with an underscore are left alone.
]]
local lintTypes = require("@std/commands/lint/types")
local path = require("@std/path")
local syntax = require("@std/syntax")
local visitorLib = require("@std/syntax/visitor")

local name = "shadowing"

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { lintTypes.LintViolation }
	local violations: { lintTypes.LintViolation } = {}
	local scopes: { { [string]: true } } = {}
	local visitor = visitorLib.create()

	local function declare(variable: syntax.CstLocal)
		local variableName = variable.name.text

		if variableName:sub(1, 1) == "_" then
			return
		end

		for _, scope in scopes do
			if scope[variableName] then
				local violation: lintTypes.LintViolation = {
					lintname = name,
					location = variable.location,
					message = `shadowing variable \`{variableName}\``,
					severity = "warning",
					sourcepath = sourcepath,
				}
				table.insert(violations, violation)
				break
			end
		end

		scopes[#scopes][variableName] = true
	end

	local function pushScope()
		table.insert(scopes, {} :: { [string]: true })
	end

	local function popScope()
		table.remove(scopes)
	end

	function visitor.visitStatBlock(_block: syntax.CstStatBlock)
		pushScope()
		return true
	end

	visitor.visitStatBlockEnd = popScope

	-- Declared before the values are visited, so a callback parameter in the value that reuses the name is caught.
	function visitor.visitStatLocalDeclaration(stat: syntax.CstStatLocal)
		for _, variable in stat.variables do
			declare(variable)
		end

		return true
	end

	function visitor.visitStatLocalFunction(stat: syntax.CstStatLocalFunction)
		declare(stat.name)
		return true
	end

	function visitor.visitExprFunction(func: syntax.CstExprFunction)
		pushScope()

		for _, parameter in func.parameters do
			declare(parameter)
		end

		return true
	end

	visitor.visitExprFunctionEnd = popScope

	function visitor.visitStatFor(stat: syntax.CstStatFor)
		pushScope()
		declare(stat.variable)
		return true
	end

	visitor.visitStatForEnd = popScope

	function visitor.visitStatForIn(stat: syntax.CstStatForIn)
		pushScope()

		for _, variable in stat.variables do
			declare(variable)
		end

		return true
	end

	visitor.visitStatForInEnd = popScope

	visitorLib.visitBlock(cst, visitor)

	return violations
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
