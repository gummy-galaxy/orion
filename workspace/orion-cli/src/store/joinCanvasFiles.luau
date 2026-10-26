local json = require("@std/json")

local fileNames = require("@root/fileNames")
local getStringField = require("@root/getStringField")
local isOrderKey = require("@root/order/isOrderKey")
local storeTypes = require("@root/store/types")

type StoredEntry = storeTypes.StoredEntry

type Found = { id: string, object: json.Object, order: string? }

local function parseObject(files: { [string]: string }, file: string): json.Object
	local object = json.asObject(json.deserialize(files[file]) :: json.Value)
	assert(object, `{file} must be a JSON object`)
	return object
end

--[[
	Entries come in the order of their keys, with ties broken by id, as when two
	branches each added one at the end. Entries without a key come after them,
	those listed in an older `canvas.json`'s order first.
]]
local function collectEntries(found: { Found }, legacyOrder: json.Value): json.Array
	local listed: { [string]: number } = {}

	for position, id in json.asArray(legacyOrder) or {} do
		if type(id) == "string" and listed[id] == nil then
			listed[id] = position
		end
	end

	table.sort(found, function(a, b)
		if (a.order == nil) ~= (b.order == nil) then
			return a.order ~= nil
		elseif a.order and b.order and a.order ~= b.order then
			return (a.order :: string) < (b.order :: string)
		end

		local aListed, bListed = listed[a.id] or math.huge, listed[b.id] or math.huge
		return if aListed ~= bListed then aListed < bListed else a.id < b.id
	end)

	local entries: json.Array = {}

	for _, item in found do
		table.insert(entries, item.object)
	end

	return entries
end

--[[
	Joins a canvas folder's files, keyed by path as `splitDocObject` writes
	them, back into one canvas object. The order key and field times each node
	and link file keeps come back apart from the canvas, by path.
]]
local function joinCanvasFiles(files: { [string]: string }): (json.Object, { [string]: StoredEntry })
	assert(files[fileNames.document], `a canvas folder needs a {fileNames.document}`)

	local document = parseObject(files, fileNames.document)
	local legacyOrder = json.asObject(document.order) or json.object({})
	document.order = nil

	local byFolder: { [string]: { Found } } = { [fileNames.nodes] = {}, [fileNames.links] = {} }
	local stored: { [string]: StoredEntry } = {}

	for file in files do
		local folder = file:match("^([^/]+)/")
		local found = if folder then byFolder[folder] else nil

		if found then
			local object = parseObject(files, file)
			local id = getStringField(object.id)
			local order = if isOrderKey(object.order) then object.order :: string else nil
			local changedAt = json.asObject(object.changedAt)
			object.order = nil
			object.changedAt = nil

			if id then
				table.insert(found, { id = id, object = object, order = order })
				stored[file] = { order = order, changedAt = changedAt }
			end
		end
	end

	document.nodes = collectEntries(byFolder[fileNames.nodes], legacyOrder.nodes)
	document.links = collectEntries(byFolder[fileNames.links], legacyOrder.links)

	if files[fileNames.localState] then
		for key, value in parseObject(files, fileNames.localState) do
			if type(key) == "string" then
				document[key] = value
			end
		end
	end

	return document, stored
end

return joinCanvasFiles
