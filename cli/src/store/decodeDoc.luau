local json = require("@std/json")

local fillPullFacts = require("@root/github/fillPullFacts")
local getStringField = require("@root/getStringField")
local migrateItem = require("@root/migrations/migrateItem")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Link = types.Link
type Source = types.Source

local function asNumber(value: json.Value): number?
	return if type(value) == "number" then value else nil
end

local function getStrings(value: json.Value): { string }?
	local array = json.asArray(value)

	if not array then
		return nil
	end

	local result = {}

	for _, entry in array do
		if type(entry) == "string" then
			table.insert(result, entry)
		end
	end

	return result
end

-- Reads a data file's text into a document, filling in defaults and moving older card fields onto refs.
local function decodeDoc(text: string): Doc
	local root = json.asObject(json.deserialize(text) :: json.Value)
	assert(root, "Orion data must be a JSON object")

	local nodes: { Item } = {}

	for _, raw in json.asArray(root.nodes) or {} do
		local object = json.asObject(raw)
		local id = if object then getStringField(object.id) else nil
		local kind = if object then getStringField(object.type) else nil

		if object and id and kind then
			local position = json.asObject(object.position) or json.object({})
			table.insert(nodes, {
				id = id,
				type = kind,
				position = { x = asNumber(position.x) or 0, y = asNumber(position.y) or 0 },
				parentId = getStringField(object.parentId),
				width = asNumber(object.width),
				height = asNumber(object.height),
				data = json.asObject(object.data) or json.object({}),
			})
		end
	end

	local links: { Link } = {}

	for _, raw in json.asArray(root.links) or {} do
		local object = json.asObject(raw)
		local from = if object then getStringField(object.from) else nil
		local to = if object then getStringField(object.to) else nil

		if object and from and to then
			table.insert(links, {
				id = getStringField(object.id) or `{from}>{to}`,
				from = from,
				to = to,
				kind = getStringField(object.kind) or "blocks",
				origin = getStringField(object.origin),
				label = getStringField(object.label),
			})
		end
	end

	local settings = json.asObject(root.settings) or json.object({})
	local sources: { Source } = {}
	local cover = getStringField(settings.cover)
	local background = getStringField(settings.background)
	local header = getStringField(settings.header)

	for _, raw in json.asArray(settings.sources) or {} do
		local source = json.asObject(raw)

		if source and type(source.id) == "string" and type(source.kind) == "string" then
			table.insert(sources, {
				id = source.id,
				kind = source.kind,
				host = getStringField(source.host),
				owners = getStrings(source.owners),
				include = getStrings(source.include),
				exclude = getStrings(source.exclude),
				command = getStrings(source.command),
				browse = getStringField(source.browse),
			})
		end
	end

	local version = asNumber(root.version) or 1
	local owner = getStringField(settings.githubOwner)

	if not owner then
		for _, source in sources do
			if source.kind == "github" then
				owner = if source.owners then source.owners[1] else nil
				break
			end
		end
	end

	owner = owner or "flipbook-labs"

	-- Cards from before refs keep their old fields until read. Remove at 0.1.0 with the rest of `migrations/`.
	for _, item in nodes do
		if
			item.type == "task"
			and (
				version < 2
				or item.data.pr ~= nil
				or item.data.external ~= nil
				or item.data.github ~= nil
				or item.data.activity ~= nil
				or item.data.sources ~= nil
				or item.data.issue ~= nil
				or item.data.branch ~= nil
				or item.data.host ~= nil
			)
		then
			migrateItem(item, owner, sources)
		end

		if item.type == "task" then
			fillPullFacts(item)
		end
	end

	return {
		version = 2,
		revision = asNumber(root.revision) or 0,
		settings = { sources = sources, cover = cover, background = background, header = header },
		nodes = nodes,
		links = links,
		github = json.asObject(root.github),
		suggestions = json.asObject(root.suggestions),
		raw = json.object(root),
	}
end

return decodeDoc
