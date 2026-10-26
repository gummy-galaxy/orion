local json = require("@std/json")

local findRef = require("@root/refs/findRef")
local getRefs = require("@root/refs/getRefs")
local graphTypes = require("@root/graph/types")
local isGroup = require("@root/graph/isGroup")
local types = require("@root/types")

type Item = types.Item

-- A node's value for a query field, as text, or nil when it has none. For
-- `ref` it's the first ref's key, which sorting uses; matching checks every
-- ref itself.
local function getFieldValue(item: Item, derived: graphTypes.Derived, field: string): string?
	local value: json.Value = nil

	if field == "kind" then
		value = if isGroup(item) then "group" elseif item.type == "image" then "image" else item.data.itemKind or "step"
	elseif field == "status" then
		value = derived.status[item.id]
	elseif field == "recordedStatus" then
		value = item.data.status
	elseif field == "group" then
		value = item.parentId
	elseif field == "snoozed" then
		-- Groups can't be snoozed, so they have no value for this field.
		value = if isGroup(item) then nil else tostring(derived.snoozed[item.id] ~= nil)
	elseif field == "draft" then
		local pull = findRef(item, "pull")
		value = if pull and pull.details then pull.details.draft else nil
	elseif field == "pr" then
		local pull = findRef(item, "pull")
		value = if pull then pull.key:match("#(%d+)$") else nil
	elseif field == "ref" then
		local first = getRefs(item)[1]
		value = if first then first.key else nil
	else
		value = item.data[field]
	end

	if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
		return tostring(value)
	end

	return nil
end

return getFieldValue
