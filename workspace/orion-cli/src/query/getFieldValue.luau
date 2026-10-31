local json = require("@std/json")

local findRef = require("@root/refs/findRef")
local getItemTypes = require("@root/cardTypes/getItemTypes")
local getRefs = require("@root/refs/getRefs")
local isGroup = require("@root/graph/isGroup")
local queryTypes = require("@root/query/types")
local types = require("@root/types")

type Item = types.Item

-- A node's value for a query field, as text, or nil when it has none. For
-- `ref` it's the first ref's key and for `group` the path of labels to the
-- group, which sorting uses; matching checks every ref and each way of naming
-- the group itself.
local function getFieldValue(scope: queryTypes.Scope, item: Item, field: string): string?
	local derived = scope.derived
	local value: json.Value = nil

	if field == "kind" then
		local itemTypes = getItemTypes(item)
		value = if itemTypes then itemTypes.primary else "group"
	elseif field == "status" then
		value = derived.status[item.id]
	elseif field == "recordedStatus" then
		value = item.data.status
	elseif field == "group" then
		local path = if item.parentId then scope.groupPaths[item.parentId] else nil
		value = if path then table.concat(path, " / ") else item.parentId
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
	elseif field == "priority" then
		for _, ref in getRefs(item) do
			if ref.details and type(ref.details.priority) == "string" then
				value = ref.details.priority
				break
			end
		end
	else
		value = item.data[field]
	end

	if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
		return tostring(value)
	end

	return nil
end

return getFieldValue
