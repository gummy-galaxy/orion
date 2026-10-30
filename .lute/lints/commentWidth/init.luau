--[[
	Warns when a comment runs past 80 columns, counting a tab as four, and
	suggests the comment rewrapped to fit, so `lute lint --auto-fix` wraps it.
	Wrapping refills each paragraph of a run of `--` lines, or of the inside of
	a `--[[` block. A blank line, a directive, or a more deeply indented line
	ends a paragraph and stays as written. A word too long to fit gets a line of
	its own, and a comment after code is reported without a fix.
]]
local lintTypes = require("@std/commands/lint/types")
local path = require("@std/path")
local query = require("@std/syntax/query")
local syntax = require("@std/syntax")
local utils = require("@std/syntax/utils")
local visitorLib = require("@std/syntax/visitor")

local name = "comment_width"

local MAX_WIDTH = 80
local TAB_WIDTH = 4

type Comment = {
	trivia: syntax.Trivia,
	line: number,
	indent: string,
	body: string,
	-- Blank, a directive, or indented further: kept as written.
	isLoose: boolean,
}

local function getWidth(text: string): number
	local width = 0

	for index = 1, #text do
		if text:sub(index, index) == "\t" then
			width += TAB_WIDTH - width % TAB_WIDTH
		else
			width += 1
		end
	end

	return width
end

local function isTooWide(lines: { string }): boolean
	for _, line in lines do
		if getWidth(line) > MAX_WIDTH then
			return true
		end
	end

	return false
end

-- Fills `words` into lines that start with `prefix` and fit when they can.
local function wrapWords(prefix: string, words: { string }): { string }
	local lines: { string } = {}
	local line = prefix .. words[1]

	for index = 2, #words do
		local candidate = `{line} {words[index]}`

		if getWidth(candidate) <= MAX_WIDTH then
			line = candidate
		else
			table.insert(lines, line)
			line = prefix .. words[index]
		end
	end

	table.insert(lines, line)

	return lines
end

local function getWords(texts: { string }): { string }
	local words: { string } = {}

	for _, text in texts do
		for word in text:gmatch("%S+") do
			table.insert(words, word)
		end
	end

	return words
end

local function isSameLines(first: { string }, second: { string }): boolean
	if #first ~= #second then
		return false
	end

	for index, line in first do
		if line ~= second[index] then
			return false
		end
	end

	return true
end

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

local function getComments(cst: syntax.CstStatBlock): { syntax.Trivia }
	local comments: { syntax.Trivia } = {}
	local visitor = visitorLib.create()

	local function collect(trivia: { syntax.Trivia })
		for _, piece in trivia do
			if piece.tag ~= "whitespace" then
				table.insert(comments, piece)
			end
		end
	end

	function visitor.visitToken(token: syntax.CstToken)
		collect(token.leadingTrivia)
		collect(token.trailingTrivia)
		return true
	end

	visitorLib.visitBlock(cst, visitor)

	table.sort(comments, function(a: syntax.Trivia, b: syntax.Trivia)
		return a.location < b.location
	end)

	return comments
end

-- Wraps one paragraph of `--` comments, or returns nil when it already fits.
local function wrapLineParagraph(paragraph: { Comment }): string?
	local original: { string } = {}
	local bodies: { string } = {}

	for _, comment in paragraph do
		table.insert(original, comment.indent .. comment.trivia.text)
		table.insert(bodies, comment.body)
	end

	if not isTooWide(original) then
		return nil
	end

	local indent = paragraph[1].indent
	local wrapped = wrapWords(`{indent}-- `, getWords(bodies))

	if isSameLines(wrapped, original) then
		return nil
	end

	return table.concat(wrapped, "\n"):sub(#indent + 1)
end

-- Splits a run of `--` comments into the paragraphs wrapping refills.
local function getLineParagraphs(run: { Comment }): { { Comment } }
	local paragraphs: { { Comment } } = {}
	local paragraph: { Comment } = {}

	local function finish()
		if #paragraph > 0 then
			table.insert(paragraphs, paragraph)
			paragraph = {}
		end
	end

	for _, comment in run do
		if comment.isLoose then
			finish()
		else
			table.insert(paragraph, comment)
		end
	end

	finish()

	return paragraphs
end

-- Rewraps the inside of a `--[[` block, or returns nil when it already fits.
local function wrapBlock(text: string): string?
	local lines = text:split("\n")

	if not isTooWide(lines) then
		return nil
	end

	local closing = lines[#lines]

	if #lines < 3 or not lines[1]:match("^%-%-%[=*%[$") or not closing:match("^%s*%]=*%]$") then
		return nil
	end

	local inside = { table.unpack(lines, 2, #lines - 1) }
	local baseIndent: string? = nil

	for _, line in inside do
		if line:match("%S") then
			baseIndent = line:match("^%s*")
			break
		end
	end

	if baseIndent == nil then
		return nil
	end

	local result: { string } = { lines[1] }
	local paragraph: { string } = {}

	local function finish()
		if #paragraph == 0 then
			return
		end

		for _, line in wrapWords(baseIndent :: string, getWords(paragraph)) do
			table.insert(result, line)
		end

		paragraph = {}
	end

	for _, line in inside do
		if line:match("^%s*(.-)%s*$") ~= "" and line:match("^%s*") == baseIndent then
			table.insert(paragraph, line)
		else
			finish()
			table.insert(result, line)
		end
	end

	finish()
	table.insert(result, closing)

	if isSameLines(result, lines) then
		return nil
	end

	return table.concat(result, "\n")
end

local function lint(cst: syntax.CstStatBlock, sourcepath: path.Path?): { lintTypes.LintViolation }
	local violations: { lintTypes.LintViolation } = {}
	local sourceLines = getSourceLines(cst)

	local typeTables = query.findAllFromRoot(cst, utils.isTypeTable).nodes

	local function report(location: syntax.Span, fix: string?)
		-- Lute's suppression check crashes on the properties of a table type,
		-- which have no location, when it looks inside one for a violation. So
		-- a comment inside one is reported on the outermost table type around
		-- it, and the fix keeps the comment's own location.
		local reported = location

		for _, typeTable in typeTables do
			if syntax.span.subsumes(typeTable.location, reported) then
				reported = typeTable.location
			end
		end

		local violation: lintTypes.LintViolation = {
			lintname = name,
			location = reported,
			message = `comment on line {location.beginLine} is wider than {MAX_WIDTH} columns`,
			severity = "warning",
			sourcepath = sourcepath,
			suggestedfix = if fix then { location = location, fix = fix } else nil,
		}
		table.insert(violations, violation)
	end

	local runs: { { Comment } } = {}
	local run: { Comment }? = nil

	for _, trivia in getComments(cst) do
		local line = trivia.location.beginLine
		local sourceLine = sourceLines[line] or ""
		local before = sourceLine:sub(1, trivia.location.beginColumn - 1)

		if before:match("%S") then
			if getWidth(sourceLine) > MAX_WIDTH then
				report(trivia.location, nil)
			end

			run = nil
			continue
		end

		if trivia.tag == "blockcomment" then
			local fix = wrapBlock(trivia.text)
			local lines = trivia.text:split("\n")
			lines[1] = before .. lines[1]

			if fix or isTooWide(lines) then
				report(trivia.location, fix)
			end

			run = nil
			continue
		end

		local text = trivia.text
		local body = text:match("^%-%-+%s?(.-)%s*$") or ""
		local comment: Comment = {
			trivia = trivia,
			line = line,
			indent = before,
			body = body,
			isLoose = body == ""
				or text:match("^%-%-[!%-]") ~= nil
				or text:match("^%-%-%s%s") ~= nil
				or text:find("lute-lint-", 1, true) ~= nil,
		}
		local previous = if run then run[#run] else nil

		if run and previous and previous.line == line - 1 and previous.indent == before then
			table.insert(run, comment)
		else
			run = { comment }
			table.insert(runs, run)
		end
	end

	for _, lineRun in runs do
		for _, paragraph in getLineParagraphs(lineRun) do
			local fix = wrapLineParagraph(paragraph)

			if fix then
				local first = paragraph[1].trivia.location
				local last = paragraph[#paragraph].trivia.location
				local location = syntax.span.create({
					beginLine = first.beginLine,
					beginColumn = first.beginColumn,
					endLine = last.endLine,
					endColumn = last.endColumn,
				})
				report(location, fix)
			end
		end

		for _, comment in lineRun do
			if comment.isLoose and getWidth(comment.indent .. comment.trivia.text) > MAX_WIDTH then
				report(comment.trivia.location, nil)
			end
		end
	end

	table.sort(violations, function(a: lintTypes.LintViolation, b: lintTypes.LintViolation)
		return a.location < b.location
	end)

	return violations
end

local rule: lintTypes.LintRule = {
	name = name,
	lint = lint,
}

return table.freeze(rule)
