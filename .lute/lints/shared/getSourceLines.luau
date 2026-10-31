local syntax = require("@std/syntax")
local visitorLib = require("@std/syntax/visitor")

-- Rebuilds the source from the tokens and the trivia around them.
local function getSourceLines(cst: syntax.CstStatBlock): { string }
	local tokens: { syntax.CstToken } = {}
	local visitor = visitorLib.create()

	function visitor.visitToken(token: syntax.CstToken)
		table.insert(tokens, token)
		return true
	end

	visitorLib.visitBlock(cst, visitor)

	table.sort(tokens, function(a: syntax.CstToken, b: syntax.CstToken)
		return a.location < b.location
	end)

	local pieces: { string } = {}

	for _, token in tokens do
		for _, trivia in token.leadingTrivia do
			table.insert(pieces, trivia.text)
		end

		table.insert(pieces, token.text)

		for _, trivia in token.trailingTrivia do
			table.insert(pieces, trivia.text)
		end
	end

	return table.concat(pieces):split("\n")
end

return getSourceLines
