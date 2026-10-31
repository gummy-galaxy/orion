local json = require("@std/json")

local encodeStableJson = require("@root/storage/files/encodeStableJson")
local getEntryFields = require("@root/storage/files/getEntryFields")

local DATA_PREFIX = "data."

local function getTime(entry: json.Object, field: string): string
	local changedAt = json.asObject(entry.changedAt)
	local time = if changedAt then changedAt[field] else nil
	return if type(time) == "string" then time else ""
end

local function encodeField(value: json.Value?): string
	return if value == nil then "" else encodeStableJson(value)
end

--[[
	Merges two versions of one node or link file, as they're stored with
	`changedAt`, keeping the newer value of each field. A field one side removed
	counts as changed when it was removed, so a newer removal wins over an older
	edit. On a tie the larger encoded value wins, so the merge comes out the
	same whichever side is which.
]]
local function mergeEntries(ours: json.Object, theirs: json.Object): json.Object
	assert(ours.id == theirs.id, "only two versions of the same entry merge")

	local ourFields, theirFields = getEntryFields(ours), getEntryFields(theirs)
	local merged = json.object({ id = ours.id })
	local changedAt = json.object({})
	local paths: { [string]: boolean } = {}

	for _, changed in { json.asObject(ours.changedAt) or {}, json.asObject(theirs.changedAt) or {} } do
		for field in changed do
			if type(field) == "string" then
				paths[field] = true
			end
		end
	end

	for _, fields in { ourFields, theirFields } do
		for field in fields do
			paths[field] = true
		end
	end

	if json.asObject(ours.data) or json.asObject(theirs.data) then
		merged.data = json.object({})
	end

	for field in paths do
		local ourTime, theirTime = getTime(ours, field), getTime(theirs, field)
		local ourValue, theirValue = ourFields[field], theirFields[field]
		local takesTheirs = theirTime > ourTime
			or (theirTime == ourTime and encodeField(theirValue) > encodeField(ourValue))
		local value = if takesTheirs then theirValue else ourValue
		local time = if takesTheirs then theirTime else ourTime

		if time ~= "" then
			changedAt[field] = time
		end

		if value == nil then
			continue
		elseif field:sub(1, #DATA_PREFIX) == DATA_PREFIX then
			(merged.data :: json.Object)[field:sub(#DATA_PREFIX + 1)] = value
		else
			merged[field] = value
		end
	end

	if next(changedAt) then
		merged.changedAt = changedAt
	end

	return merged
end

return mergeEntries
