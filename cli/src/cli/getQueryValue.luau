local json = require("@std/json")

local graphTypes = require("@root/graph/types")
local isGroup = require("@root/graph/isGroup")
local render = require("@root/render")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

-- A query result: the item's fields as JSON, with groups named as groups.
local function getQueryValue(doc: Doc, derived: graphTypes.Derived, item: Item): json.Object
	local value = render.itemJson(doc, derived, item)

	if isGroup(item) then
		value.kind = "group"
		value.status = nil
		value.recordedStatus = nil
	end

	return value
end

return getQueryValue
