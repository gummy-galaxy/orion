local derive = require("@root/graph/derive")
local getLabel = require("@root/graph/getLabel")
local matchesExpression = require("@root/query/matchesExpression")
local parseExpression = require("@root/query/parseExpression")
local resolveRef = require("@root/adapters/resolveRef")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Expression = parseExpression.Expression

-- The fields a selector can name, each matched the way --where matches it.
local SELECTORS = { label = true, ref = true, pr = true }

local function comparison(field: string, value: string): Expression
	return { kind = "comparison", field = field, operator = "=", value = value }
end

-- A value with a URL or a source prefix is a ref that --ref would resolve, and it matches by that ref's key.
-- A bare value is already a key, such as owner/name#12 or ABC-12.
local function refKey(value: string, doc: Doc): string
	if value:match("^https?://") or value:match("^[a-z][a-z0-9%-]*:") then
		return resolveRef(value, doc.settings.sources).ref.key
	end

	return value
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

-- Strips one pair of matching quotes, so label:"Extract slider" and label:'Extract slider' select the same card.
local function unquote(value: string): string
	return value:match('^"(.*)"$') or value:match("^'(.*)'$") or value
end

-- Resolves an id argument to the id of one item or group. A plain id passes through unchanged, and getItem reports it
-- if it's missing. A selector such as label:"Extract slider", ref:jira:ABC-12, or pr:86 matches the way --where does,
-- and it has to match exactly one item, so an ambiguous selector lists its matches instead of picking one.
local function resolveId(doc: Doc, input: string): string
	local selector, rest = input:match("^(%a+):(.*)$")

	if not selector or not rest then
		return input
	end

	assert(SELECTORS[selector], `"{input}" uses an unknown selector; use label:"...", ref:..., or pr:...`)
	local value = unquote(rest)
	assert(value ~= "", `{selector}: needs a value`)

	local expression = selectorExpression(selector, value, doc)
	local derived = derive(doc)
	local matches: { Item } = {}

	for _, item in doc.nodes do
		if matchesExpression(derived, item, expression) then
			table.insert(matches, item)
		end
	end

	assert(#matches > 0, `{input} matches no item or group`)

	if #matches > 1 then
		local lines: { string } = {}

		for _, item in matches do
			table.insert(lines, `  {item.id} · {getLabel(item)}`)
		end

		error(`{input} matches {#matches} items; use one of their ids:\n{table.concat(lines, "\n")}`, 0)
	end

	return matches[1].id
end

return resolveId
