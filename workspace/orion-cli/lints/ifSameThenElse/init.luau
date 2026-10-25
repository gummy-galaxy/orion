--[[
	Warns when a branch of an `if` statement has the same body as an earlier branch, which usually means the conditions
	should be combined. Bodies are compared without their whitespace and comments.
]]
local lintTypes = require("@std/commands/lint/types")
local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")
local visitorLib = require("@std/syntax/visitor")

local name = "if_same_then_else"

-- Joins the block's token texts, which leaves out the whitespace and comments around them.
local function getBodyText(block: syntax.CstStatBlock): string
	local tokens: { string } = {}
	local visitor = visitorLib.create()

	function visitor.visitToken(token: syntax.CstToken)
		table.insert(tokens, token.text)
		return true
	end

	visitorLib.visitBlock(block, visitor)

	return table.concat(tokens, "\0")
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { lintTypes.LintViolation }
	local violations: { lintTypes.LintViolation } = {}

	for _, stat in query.findAllFromRoot(cst, utils.isStatIf).nodes do
		local blocks = { stat.thenBlock }

		for _, branch in stat.elseifs do
			table.insert(blocks, branch.thenBlock)
		end

		if stat.elseBlock then
			table.insert(blocks, stat.elseBlock)
		end

		local seen: { [string]: true } = {}

		for _, block in blocks do
			if #block.statements == 0 then
				continue
			end

			local text = getBodyText(block)

			if seen[text] then
				local violation: lintTypes.LintViolation = {
					lintname = name,
					location = block.location,
					message = "this has the same block as a previous if",
					severity = "warning",
					sourcepath = sourcepath,
				}
				table.insert(violations, violation)
			end

			seen[text] = true
		end
	end

	return violations
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
