local json = require("@std/json")

local syncPlacements = require("@root/canvas/placement/syncPlacements")
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

-- The JSON object a document is stored as. Fields Orion doesn't know about,
-- kept in `raw`, pass through unchanged. Nodes keep no position or group,
-- since those belong to placements, which the document's nodes bring up to date
-- first.
local function encodeDocObject(doc: Doc): json.Object
	syncPlacements(doc)

	local nodes: json.Array = {}

	for _, item in doc.nodes do
		local object: json.Object = json.object({ id = item.id, type = item.type, data = json.object(item.data) })
		object.width = item.width
		object.height = item.height
		table.insert(nodes, object)
	end

	local placements: json.Array = {}

	for _, placement in doc.placements do
		local object = json.object({
			id = placement.id,
			node = placement.node,
			position = json.object({ x = placement.position.x, y = placement.position.y }),
		})
		object.parentId = placement.parentId
		table.insert(placements, object)
	end

	local links: json.Array = {}

	for _, link in doc.links do
		local object = json.object({ id = link.id, from = link.from, to = link.to, kind = link.kind })
		object.origin = link.origin
		object.label = link.label
		table.insert(links, object)
	end

	local root = json.object(doc.raw or {})
	root.version = 3
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
	root.placements = placements
	root.github = doc.github
	root.suggestions = doc.suggestions
	root.repositories = doc.repositories

	return root
end

return encodeDocObject
