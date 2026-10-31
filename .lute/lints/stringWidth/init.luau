--[[
	Warns when a line holding a string runs past 120 columns, counting a tab as
	four. StyLua wraps code to that width but never splits a string, so a long
	one needs splitting by hand: join pieces with `..` across lines, or put the
	lines in a table and `table.concat` them.
]]
local lintTypes = require("@std/commands/lint/types")
local path = require("@std/path")
local syntax = require("@std/syntax")
local visitorLib = require("@std/syntax/visitor")

local getSourceLines = require("@repository/.lute/lints/shared/getSourceLines")
local getWidth = require("@repository/.lute/lints/shared/getWidth")

local name = "string_width"

local MAX_WIDTH = 120

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { lintTypes.LintViolation }
	local violations: { lintTypes.LintViolation } = {}
	local sourceLines = getSourceLines(cst)
	local reportedLines: { [number]: true } = {}
	local visitor = visitorLib.create()

	local function check(location: syntax.Span)
		for line = location.beginLine, location.endLine do
			if not reportedLines[line] and getWidth(sourceLines[line] or "") > MAX_WIDTH then
				reportedLines[line] = true

				local violation: lintTypes.LintViolation = {
					lintname = name,
					location = location,
					message = `string on line {line} is wider than {MAX_WIDTH} columns`,
					severity = "warning",
					sourcepath = sourcepath,
				}
				table.insert(violations, violation)
			end
		end
	end

	function visitor.visitExprConstantString(expression: syntax.CstExprConstantString)
		check(expression.location)
		return true
	end

	function visitor.visitExprInterpString(expression: syntax.CstExprInterpString)
		check(expression.location)
		return true
	end

	visitorLib.visitBlock(cst, visitor)

	return violations
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
