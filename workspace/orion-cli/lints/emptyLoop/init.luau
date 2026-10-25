--[[
	Warns on `while`, `for`, and `repeat` loops with nothing in their body. A comment counts as a body, so a loop that
	drains an iterator can say so.
]]
local lintTypes = require("@std/commands/lint/types")
local path = require("@std/path")
local syntax = require("@std/syntax")
local visitorLib = require("@std/syntax/visitor")

local name = "empty_loop"

local function hasComment(trivia: { syntax.Trivia }): boolean
	for _, piece in trivia do
		if piece.tag ~= "whitespace" then
			return true
		end
	end

	return false
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { lintTypes.LintViolation }
	local violations: { lintTypes.LintViolation } = {}
	local visitor = visitorLib.create()

	local function check(
		loop: syntax.CstStat,
		body: syntax.CstStatBlock,
		opening: syntax.CstToken,
		closing: syntax.CstToken
	)
		if #body.statements > 0 or hasComment(opening.trailingTrivia) or hasComment(closing.leadingTrivia) then
			return
		end

		local violation: lintTypes.LintViolation = {
			lintname = name,
			location = loop.location,
			message = "empty loop block",
			severity = "warning",
			sourcepath = sourcepath,
		}
		table.insert(violations, violation)
	end

	function visitor.visitStatWhile(stat: syntax.CstStatWhile)
		check(stat, stat.body, stat.doKeyword, stat.endKeyword)
		return true
	end

	function visitor.visitStatFor(stat: syntax.CstStatFor)
		check(stat, stat.body, stat.doKeyword, stat.endKeyword)
		return true
	end

	function visitor.visitStatForIn(stat: syntax.CstStatForIn)
		check(stat, stat.body, stat.doKeyword, stat.endKeyword)
		return true
	end

	function visitor.visitStatRepeat(stat: syntax.CstStatRepeat)
		check(stat, stat.body, stat.repeatKeyword, stat.untilKeyword)
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
