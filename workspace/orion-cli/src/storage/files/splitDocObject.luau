local json = require("@std/json")

local assignOrderKeys = require("@root/common/order/assignOrderKeys")
local encodeStableJson = require("@root/storage/files/encodeStableJson")
local fileNames = require("@root/fileNames")
local getEntryFields = require("@root/storage/files/getEntryFields")
local getEntryFileName = require("@root/storage/files/getEntryFileName")
local getStringField = require("@root/common/getStringField")
local sameValue = require("@root/canvas/operations/sameValue")
local storeTypes = require("@root/storage/types")

type CanvasSnapshot = storeTypes.CanvasSnapshot

-- Fields that record this machine's view of a canvas rather than the canvas
-- itself, kept out of the shared files. The revision counts this machine's
-- writes, so `canvas.json` only changes when the canvas's own fields do.
local LOCAL_FIELDS: { [string]: boolean } = { github = true, revision = true, suggestions = true, repositories = true }

local function copyObject(object: json.Object?): json.Object
	local copy = json.object({})

	for key, value in object or {} do
		copy[key] = value
	end

	return copy
end

local function parseEntry(text: string?): json.Object?
	if text == nil then
		return nil
	end

	local succeeded, value = pcall(json.deserialize, text)
	return if succeeded then json.asObject(value) else nil
end

--[[
	The text of an entry's file, with its order key and when each field last
	changed. A field that differs from the file it replaces, or that's new or
	gone, is stamped `now`, and the rest keep their times. An entry whose fields
	all match skips comparing them field by field.
]]
local function stampEntry(entry: json.Object, key: string, file: string, previous: CanvasSnapshot?, now: string): string
	local stored = if previous and previous.entries then previous.entries[file] else nil
	local previousText = if previous and previous.files then previous.files[file] else nil
	entry.order = key

	if stored and stored.order == key and previousText then
		entry.changedAt = stored.changedAt
		local text = encodeStableJson(entry)

		if text == previousText then
			return text
		end
	end

	local previousEntry = parseEntry(previousText)
	local changedAt = copyObject(if previousEntry then json.asObject(previousEntry.changedAt) else nil)
	local fields = getEntryFields(entry)
	local previousFields = if previousEntry then getEntryFields(previousEntry) else {}

	for field, value in fields do
		if previousEntry == nil or not sameValue(value, previousFields[field]) then
			changedAt[field] = now
		end
	end

	for field in previousFields do
		if fields[field] == nil then
			changedAt[field] = now
		end
	end

	entry.changedAt = changedAt
	return encodeStableJson(entry)
end

local function splitEntries(
	files: { [string]: string },
	folder: string,
	entries: json.Value,
	getId: (json.Object) -> string?,
	previous: CanvasSnapshot?,
	now: string
)
	local kept: { { entry: json.Object, file: string } } = {}
	local previousKeys: { [number]: string? } = {}

	for _, value in json.asArray(entries) or {} do
		local object = json.asObject(value)
		local id = if object then getId(object) else nil

		if object and id then
			local entry = copyObject(object)
			entry.id = id
			entry.order = nil
			entry.changedAt = nil

			local file = `{folder}/{getEntryFileName(id)}`
			local stored = if previous and previous.entries then previous.entries[file] else nil
			table.insert(kept, { entry = entry, file = file })
			previousKeys[#kept] = if stored then stored.order else nil
		end
	end

	local keys = assignOrderKeys(previousKeys, #kept)

	for position, item in kept do
		files[item.file] = stampEntry(item.entry, keys[position], item.file, previous, now)
	end
end

--[[
	Splits a whole canvas, in the shape `encodeDocObject` returns, into the
	files of its folder, keyed by path: `canvas.json` for the canvas's own
	fields, `nodes/<id>.json` and `links/<id>.json` for each node and link, and
	`local.json` for the revision and the other local fields. Each node and link
	file keeps an order key, so moving or adding one rewrites only its file, and
	when each of its fields last changed, compared with the files in `previous`
	and stamped `now`. A link without an id gets the one Orion has always read
	it as.
]]
local function splitDocObject(document: json.Object, previous: CanvasSnapshot?, now: string): { [string]: string }
	local files: { [string]: string } = {}
	local canvas = json.object({})
	local localState = json.object({})
	local hasLocalState = false

	for key, value in document do
		if type(key) ~= "string" or key == "nodes" or key == "links" then
			continue
		end

		if LOCAL_FIELDS[key] then
			localState[key] = value
			hasLocalState = true
		else
			canvas[key] = value
		end
	end

	splitEntries(files, fileNames.nodes, document.nodes, function(object)
		return getStringField(object.id)
	end, previous, now)
	splitEntries(files, fileNames.links, document.links, function(object)
		local from, to = getStringField(object.from), getStringField(object.to)
		return getStringField(object.id) or (if from and to then `{from}>{to}` else nil)
	end, previous, now)

	files[fileNames.document] = encodeStableJson(canvas)

	if hasLocalState then
		files[fileNames.localState] = encodeStableJson(localState)
	end

	return files
end

return splitDocObject
