local derive = require("@root/graph/derive")
local getLabel = require("@root/graph/getLabel")
local graphTypes = require("@root/graph/types")
local matchesExpression = require("@root/query/matchesExpression")
local parseExpression = require("@root/query/parseExpression")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

export type Canvas = { name: string, doc: Doc }
export type Hit = { name: string, doc: Doc, derived: graphTypes.Derived, item: Item }
export type Result = { total: number, hits: { Hit } }

type Entry = { hit: Hit, rank: number, sequence: number }

-- Lower ranks print first: a label that is the text, then a label that contains it, then a ref, then a note.
local EXACT_LABEL, LABEL, REF, NOTE = 0, 1, 2, 3

-- Quotes text as a string value for the expression engine, which only escapes quotes and backslashes.
local function quote(text: string): string
	return `"{(text:gsub('[\\"]', "\\%0"))}"`
end

-- Finds the items and groups whose label, note, or refs contain the text, using the same expression as --where.
-- Canvases are searched in the order given, and matches keep that order within each rank, up to the limit.
local function findItems(canvases: { Canvas }, text: string, limit: number): Result
	assert(text ~= "", "find needs text")
	local quoted = quote(text)
	local anywhere = parseExpression(`label ~ {quoted} or ref ~ {quoted} or note ~ {quoted}`)
	local inLabel = parseExpression(`label ~ {quoted}`)
	local inRef = parseExpression(`ref ~ {quoted}`)
	local lowered = text:lower()

	local found: { Entry } = {}

	for _, canvas in canvases do
		local derived = derive(canvas.doc)

		for _, item in canvas.doc.nodes do
			if matchesExpression(derived, item, anywhere) then
				local rank = NOTE

				if getLabel(item):lower() == lowered then
					rank = EXACT_LABEL
				elseif matchesExpression(derived, item, inLabel) then
					rank = LABEL
				elseif matchesExpression(derived, item, inRef) then
					rank = REF
				end

				table.insert(found, {
					hit = { name = canvas.name, doc = canvas.doc, derived = derived, item = item },
					rank = rank,
					sequence = #found + 1,
				})
			end
		end
	end

	table.sort(found, function(a: Entry, b: Entry)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end

		return a.sequence < b.sequence
	end)

	local hits: { Hit } = {}

	for index, entry in found do
		if index > limit then
			break
		end

		table.insert(hits, entry.hit)
	end

	return { total = #found, hits = hits }
end

return findItems
