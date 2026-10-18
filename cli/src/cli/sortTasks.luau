local graph = require("@root/graph")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- The cards that pass keep, the ones that unblock the most first.
local function sortTasks(doc: Doc, derived: graph.Derived, keep: (Item) -> boolean): { Item }
	local items: { Item } = {}

	for _, item in doc.nodes do
		if item.type == "task" and keep(item) then
			table.insert(items, item)
		end
	end

	table.sort(items, function(a, b)
		local firstLeverage, secondLeverage = derived.leverage[a.id] or 0, derived.leverage[b.id] or 0

		if firstLeverage ~= secondLeverage then
			return firstLeverage > secondLeverage
		end

		return a.id < b.id
	end)

	return items
end

return sortTasks
