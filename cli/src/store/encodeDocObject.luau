local json = require("@std/json")

local types = require("@root/types")

type Doc = types.Doc

local function getStringArray(values: { string }?): json.Array?
	if not values then
		return nil
	end

	local result: json.Array = {}

	for _, value in values do
		table.insert(result, value)
	end

	return result
end

-- The JSON object a document is stored as. Fields Orion doesn't know about, kept in `raw`, pass through unchanged.
local function encodeDocObject(doc: Doc): json.Object
	local nodes: json.Array = {}

	for _, item in doc.nodes do
		local object: json.Object = json.object({
			id = item.id,
			type = item.type,
			position = json.object({ x = item.position.x, y = item.position.y }),
			data = json.object(item.data),
		})
		object.parentId = item.parentId
		object.width = item.width
		object.height = item.height
		table.insert(nodes, object)
	end

	local links: json.Array = {}

	for _, link in doc.links do
		local object = json.object({ id = link.id, from = link.from, to = link.to, kind = link.kind })
		object.origin = link.origin
		object.label = link.label
		table.insert(links, object)
	end

	local root = json.object(doc.raw or {})
	root.version = 2
	root.revision = doc.revision
	local settings = json.object(json.asObject(root.settings) or {})
	settings.githubOwner = nil
	local sources: json.Array = {}

	for _, source in doc.settings.sources do
		local value = json.object({ id = source.id, kind = source.kind })
		value.host = source.host
		value.owners = getStringArray(source.owners)
		value.include = getStringArray(source.include)
		value.exclude = getStringArray(source.exclude)
		value.command = getStringArray(source.command)
		value.browse = source.browse
		value.dir = source.dir
		table.insert(sources, value)
	end

	settings.sources = sources
	settings.cover = doc.settings.cover
	settings.background = doc.settings.background
	settings.header = doc.settings.header
	local checkSnoozes: json.Array = {}

	for _, snooze in doc.settings.checkSnoozes do
		local value = json.object({ repo = snooze.repo, name = snooze.name, at = snooze.at })
		value["until"] = snooze.untilTime
		value.passed = getStringArray(snooze.passed)
		table.insert(checkSnoozes, value)
	end

	settings.checkSnoozes = if #checkSnoozes > 0 then checkSnoozes else nil
	root.settings = settings
	root.nodes = nodes
	root.links = links
	root.github = doc.github
	root.suggestions = doc.suggestions

	return root
end

return encodeDocObject
