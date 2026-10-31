local createScope = require("@root/canvas/query/createScope")
local getFieldValue = require("@root/canvas/query/getFieldValue")
local matchesExpression = require("@root/canvas/query/matchesExpression")
local parseExpression = require("@root/canvas/query/parseExpression")
local queryTypes = require("@root/canvas/query/types")
local types = require("@root/types")

type Item = types.Item
type Query = queryTypes.Query
type Result = queryTypes.Result

type Entry = { item: Item, values: { string | false }, sequence: number }

-- Orders two values of one field: numbers by size when both are numbers,
-- other text ignoring case. Returns nil when they tie.
local function isBefore(a: string, b: string): boolean?
	local numberA, numberB = tonumber(a), tonumber(b)

	if numberA and numberB then
		return if numberA == numberB then nil else numberA < numberB
	end

	local lowerA, lowerB = a:lower(), b:lower()

	if lowerA ~= lowerB then
		return lowerA < lowerB
	end

	return if a == b then nil else a < b
end

-- The one query engine behind `orion node query`, `--where` edits, and
-- `orion server start`'s query endpoint: selects nodes with the `--where`
-- grammar, leaves done cards out unless asked, sorts them, and returns a page.
-- Nodes without a sort field's value come last in either direction, and ties
-- keep canvas order.
local function queryItems(doc: types.Doc, query: Query): Result
	local offset = query.offset or 0

	if offset < 0 or offset % 1 ~= 0 then
		error("offset must be a whole number", 0)
	elseif query.limit and (query.limit < 1 or query.limit % 1 ~= 0) then
		error("limit must be a positive integer", 0)
	end

	local expression = if query.where then parseExpression(query.where) else nil
	local sort = query.sort or {}
	local scope = createScope(doc, query.now)
	local matches: { Entry } = {}

	for _, item in doc.nodes do
		local isShown = query.includeDone or scope.derived.status[item.id] ~= "done"

		if isShown and (expression == nil or matchesExpression(scope, item, expression)) then
			local values: { string | false } = {}

			for index, key in sort do
				values[index] = getFieldValue(scope, item, key.field) or false
			end

			table.insert(matches, { item = item, values = values, sequence = #matches + 1 })
		end
	end

	if #sort > 0 then
		table.sort(matches, function(a: Entry, b: Entry): boolean
			for index, key in sort do
				local valueA, valueB = a.values[index], b.values[index]

				if valueA == false or valueB == false then
					if valueA ~= valueB then
						return valueB == false
					end
				else
					local result = isBefore(valueA, valueB)

					if result ~= nil then
						return if key.isDescending then not result else result
					end
				end
			end

			return a.sequence < b.sequence
		end)
	end

	local last = if query.limit then math.min(#matches, offset + query.limit) else #matches
	local items: { Item } = {}

	for index = offset + 1, last do
		table.insert(items, matches[index].item)
	end

	return { total = #matches, offset = offset, items = items, derived = scope.derived }
end

return queryItems
