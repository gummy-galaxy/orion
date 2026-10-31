local printer = require("@std/syntax/printer")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")

local mutationTypes = require("./types")

type Mutation = mutationTypes.Mutation

-- Each operator swaps for the one a test should tell apart from it.
local OPERATOR_SWAPS: { [string]: string } = {
	["=="] = "~=",
	["~="] = "==",
	["<"] = "<=",
	["<="] = "<",
	[">"] = ">=",
	[">="] = ">",
	["+"] = "-",
	["-"] = "+",
	["*"] = "/",
	["/"] = "*",
	["and"] = "or",
	["or"] = "and",
}

-- Returns a copy of `source` for each small change a test suite should notice:
-- a swapped comparison, arithmetic, or logical operator, a dropped `not`, a
-- flipped boolean, or a number one higher. Type annotations are left alone.
local function findMutations(source: string): { Mutation }
	local parsed = syntax.parse(source)
	local mutations: { Mutation } = {}

	local function add(node: syntax.CstNode, line: number, column: number, original: string, replacement: string)
		table.insert(mutations, {
			line = line,
			column = column,
			original = original,
			replacement = replacement,
			source = printer.printFile(parsed, { [node] = replacement }),
		})
	end

	query
		.findAllFromRoot(parsed, function(node: syntax.CstNode): syntax.CstExpr?
			return if node.kind == "expr" then node :: syntax.CstExpr else nil
		end)
		:forEach(function(expression: syntax.CstExpr)
			local location = expression.location

			if expression.tag == "binary" then
				local operator = expression.operator
				local swap = OPERATOR_SWAPS[operator.text]

				if swap then
					add(operator, operator.location.beginLine, operator.location.beginColumn, operator.text, swap)
				end
			elseif expression.tag == "unary" and expression.operator.text == "not" then
				add(expression.operator, location.beginLine, location.beginColumn, "not", "")
			elseif expression.tag == "boolean" then
				local flipped = if expression.value then "false" else "true"
				add(expression.token, location.beginLine, location.beginColumn, expression.token.text, flipped)
			elseif expression.tag == "number" then
				add(
					expression.token,
					location.beginLine,
					location.beginColumn,
					expression.token.text,
					tostring(expression.value + 1)
				)
			end
		end)

	table.sort(mutations, function(a: Mutation, b: Mutation)
		return if a.line == b.line then a.column < b.column else a.line < b.line
	end)

	return mutations
end

return findMutations
