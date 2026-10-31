local createScope = require("@root/query/createScope")
local getCurrentKey = require("@root/github/getCurrentKey")
local getLabel = require("@root/graph/getLabel")
local matchesExpression = require("@root/query/matchesExpression")
local parseExpression = require("@root/query/parseExpression")
local raiseFailure = require("@root/raiseFailure")
local resolveRef = require("@root/adapters/resolveRef")
local selectors = require("@root/query/selectors")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Expression = parseExpression.Expression

local function comparison(field: string, value: string): Expression
	return { kind = "comparison", field = field, operator = "=", value = value }
end

-- A value with a URL or a source prefix is a ref that --ref would resolve, and
-- it matches by that ref's key. A bare value is already a key, such as
-- owner/name#12 or ABC-12. A repository that moved matches by its old name too.
local function refKey(value: string, doc: Doc): string
	if value:match("^https?://") or value:match("^[a-z][a-z0-9%-]*:") then
		return getCurrentKey(doc, resolveRef(value, doc.settings.sources).ref.key)
	end

	return getCurrentKey(doc, value)
end

local function selectorExpression(selector: string, value: string, doc: Doc): Expression
	if selector == "label" then
		return comparison("label", value)
	end

	local number = value:gsub("^#", "")
	if selector == "pr" and number:match("^%d+$") then
		return comparison("pr", number)
	end

	return comparison("ref", refKey(value, doc))
end

-- Strips one pair of matching quotes, so label:"Extract slider" and
-- label:'Extract slider' select the same card.
local function unquote(value: string): string
	return value:match('^"(.*)"$') or value:match("^'(.*)'$") or value
end

-- Resolves an id argument to the id of one item or group. A plain id passes
-- through unchanged, and getItem reports it if it's missing. A selector such as
-- label:"Extract slider", ref:jira:ABC-12, or pr:86 matches the way --where
-- does, and it has to match exactly one item, so an ambiguous selector lists
-- its matches instead of picking one.
local function resolveId(doc: Doc, input: string): string
	local selector, rest = input:match("^(%a+):(.*)$")

	if not selector or not rest then
		return input
	end

	if not selectors.byName[selector] then
		local forms: { string } = {}

		for _, known in selectors.list do
			table.insert(forms, known.form)
		end

		error(`"{input}" uses an unknown selector; use {table.concat(forms, ", ")}`, 0)
	end

	local value = unquote(rest)
	assert(value ~= "", `{selector}: needs a value`)

	local expression = selectorExpression(selector, value, doc)
	local scope = createScope(doc)
	local matches: { Item } = {}

	for _, item in doc.nodes do
		if matchesExpression(scope, item, expression) then
			table.insert(matches, item)
		end
	end

	if #matches == 0 then
		raiseFailure("missing-item", `{input} matches no item or group`)
	end

	if #matches > 1 then
		local lines: { string } = {}

		for _, item in matches do
			table.insert(lines, `  {item.id} · {getLabel(item)}`)
		end

		raiseFailure(
			"ambiguous-selector",
			`{input} matches {#matches} items; use one of their ids:\n{table.concat(lines, "\n")}`
		)
	end

	return matches[1].id
end

return resolveId
