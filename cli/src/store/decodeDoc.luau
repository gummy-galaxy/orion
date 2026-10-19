local json = require("@std/json")

local fillPullFacts = require("@root/github/fillPullFacts")
local getStringField = require("@root/getStringField")
local types = require("@root/types")

type CheckSnooze = types.CheckSnooze
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

-- Version 1 kept a card's pull request, issue, and branch in their own fields instead of refs.
local VERSION_ONE_MESSAGE = "This canvas was saved as data version 1, which Orion no longer reads. "
	.. "To upgrade it, make one change to it with an Orion built from commit 40320db6 or earlier, "
	.. "such as moving a card, then try again."

-- Reads a data file's text into a document, filling in defaults.
local function decodeDoc(text: string): Doc
	local root = json.asObject(json.deserialize(text) :: json.Value)
	assert(root, "Orion data must be a JSON object")
	assert((asNumber(root.version) or 1) >= 2, VERSION_ONE_MESSAGE)

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
	local checkSnoozes: { CheckSnooze } = {}

	for _, raw in json.asArray(settings.checkSnoozes) or {} do
		local snooze = json.asObject(raw)
		local repo = if snooze then getStringField(snooze.repo) else nil
		local name = if snooze then getStringField(snooze.name) else nil
		local at = if snooze then getStringField(snooze.at) else nil

		if snooze and repo and name and at then
			local passed: { string } = {}

			for _, id in json.asArray(snooze.passed) or {} do
				if type(id) == "string" then
					table.insert(passed, id)
				end
			end

			table.insert(
				checkSnoozes,
				{ repo = repo, name = name, untilTime = getStringField(snooze["until"]), at = at, passed = passed }
			)
		end
	end

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

	for _, item in nodes do
		if item.type == "task" then
			fillPullFacts(item)
		end
	end

	return {
		version = 2,
		revision = asNumber(root.revision) or 0,
		settings = {
			sources = sources,
			cover = cover,
			background = background,
			header = header,
			checkSnoozes = checkSnoozes,
		},
		nodes = nodes,
		links = links,
		github = json.asObject(root.github),
		suggestions = json.asObject(root.suggestions),
		raw = json.object(root),
	}
end

return decodeDoc
