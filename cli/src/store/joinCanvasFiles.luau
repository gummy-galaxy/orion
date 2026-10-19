local json = require("@std/json")

local fileNames = require("@root/fileNames")
local getStringField = require("@root/getStringField")

local function parseObject(files: { [string]: string }, file: string): json.Object
	local object = json.asObject(json.deserialize(files[file]) :: json.Value)
	assert(object, `{file} must be a JSON object`)
	return object
end

-- Entries listed in `order` come first, in that order, and any others after them sorted by id, such as a node
-- whose file arrived without Orion writing it.
local function collectEntries(byId: { [string]: json.Object }, order: json.Value): json.Array
	local entries: json.Array = {}
	local seen: { [string]: boolean } = {}

	for _, id in json.asArray(order) or {} do
		if type(id) == "string" and byId[id] and not seen[id] then
			seen[id] = true
			table.insert(entries, byId[id])
		end
	end

	local rest: { string } = {}

	for id in byId do
		if not seen[id] then
			table.insert(rest, id)
		end
	end

	table.sort(rest)

	for _, id in rest do
		table.insert(entries, byId[id])
	end

	return entries
end

-- Joins a canvas folder's files, keyed by path as `splitDocObject` writes them, back into one canvas object.
local function joinCanvasFiles(files: { [string]: string }): json.Object
	assert(files[fileNames.document], `a canvas folder needs a {fileNames.document}`)

	local document = parseObject(files, fileNames.document)
	local order = json.asObject(document.order) or json.object({})
	document.order = nil

	local byFolder: { [string]: { [string]: json.Object } } = { [fileNames.nodes] = {}, [fileNames.links] = {} }

	for file in files do
		local folder = file:match("^([^/]+)/")
		local entries = if folder then byFolder[folder] else nil

		if entries then
			local object = parseObject(files, file)
			local id = getStringField(object.id)

			if id then
				entries[id] = object
			end
		end
	end

	document.nodes = collectEntries(byFolder[fileNames.nodes], order.nodes)
	document.links = collectEntries(byFolder[fileNames.links], order.links)

	if files[fileNames.localState] then
		for key, value in parseObject(files, fileNames.localState) do
			if type(key) == "string" then
				document[key] = value
			end
		end
	end

	return document
end

return joinCanvasFiles
