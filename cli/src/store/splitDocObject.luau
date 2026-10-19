local json = require("@std/json")

local encodeStableJson = require("@root/store/encodeStableJson")
local fileNames = require("@root/fileNames")
local getEntryFileName = require("@root/store/getEntryFileName")
local getStringField = require("@root/getStringField")

-- Fields that record this machine's view of a canvas rather than the canvas itself, kept out of the shared files.
local LOCAL_FIELDS: { [string]: boolean } = { github = true, suggestions = true }

local function splitEntries(
	files: { [string]: string },
	folder: string,
	entries: json.Value,
	getId: (json.Object) -> string?
): json.Array
	local order: json.Array = {}

	for _, entry in json.asArray(entries) or {} do
		local object = json.asObject(entry)
		local id = if object then getId(object) else nil

		if object and id then
			local copy = json.object(object)
			copy.id = id
			files[`{folder}/{getEntryFileName(id)}`] = encodeStableJson(copy)
			table.insert(order, id)
		end
	end

	return order
end

--[[
	Splits a whole canvas, in the shape `encodeDocObject` returns, into the files of its folder, keyed by path:
	`canvas.json` for everything but its nodes and links, `nodes/<id>.json` and `links/<id>.json` for each of
	those, and `local.json` for the local fields. `canvas.json` lists the node and link ids in order, since their
	files don't keep it. A link without an id gets the one Orion has always read it as.
]]
local function splitDocObject(document: json.Object): { [string]: string }
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

	local nodeOrder = splitEntries(files, fileNames.nodes, document.nodes, function(object)
		return getStringField(object.id)
	end)
	local linkOrder = splitEntries(files, fileNames.links, document.links, function(object)
		local from, to = getStringField(object.from), getStringField(object.to)
		return getStringField(object.id) or (if from and to then `{from}>{to}` else nil)
	end)

	canvas.order = json.object({ nodes = nodeOrder, links = linkOrder })
	files[fileNames.document] = encodeStableJson(canvas)

	if hasLocalState then
		files[fileNames.localState] = encodeStableJson(localState)
	end

	return files
end

return splitDocObject
