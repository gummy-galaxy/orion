local json = require("@std/json")

local graph = require("@root/graph")
local render = require("@root/render")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- A query result: the item's fields as JSON, with groups named as groups.
local function getQueryValue(doc: Doc, derived: graph.Derived, item: Item): json.Object
	local value = render.itemJson(doc, derived, item)

	if graph.isGroup(item) then
		value.kind = "group"
		value.status = nil
		value.recordedStatus = nil
	end

	return value
end

return getQueryValue
