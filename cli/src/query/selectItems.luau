local derive = require("@root/graph/derive")
local matchesExpression = require("@root/query/matchesExpression")
local parseExpression = require("@root/query/parseExpression")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

local function selectItems(doc: Doc, expression: string, includeDone: boolean, now: string?): { Item }
	local parsed = parseExpression(expression)
	local derived = derive(doc, now)
	local selected: { Item } = {}

	for _, item in doc.nodes do
		if (includeDone or derived.status[item.id] ~= "done") and matchesExpression(derived, item, parsed) then
			table.insert(selected, item)
		end
	end

	return selected
end

return selectItems
