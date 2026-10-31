local json = require("@std/json")

local checkDataVersion = require("@root/storage/transactions/checkDataVersion")
local fillPullFacts = require("@root/sources/github/pulls/fillPullFacts")
local getStringField = require("@root/common/getStringField")
local migrateImageCanvas = require("@root/storage/migrations/migrateImageCanvas")
local types = require("@root/types")

type CheckSnooze = types.CheckSnooze
type Doc = types.Doc
type Item = types.Item
type Link = types.Link
type Placement = types.Placement
type Position = types.Position
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

local function getPosition(value: json.Value): Position
	local position = json.asObject(value) or json.object({})
	return { x = asNumber(position.x) or 0, y = asNumber(position.y) or 0 }
end

--[[
	Reads a whole canvas object into a document, filling in defaults. Each node
	takes its position and group from its first placement. A node from before
	placements keeps the position and group stored on it, and the next write
	moves them into a placement. Any other node has no placement.
]]
local function decodeDocObject(root: json.Object): Doc
	checkDataVersion(root)

	-- Before data version 3, every node was placed where it said, or at the
	-- origin.
	local isBeforePlacements = type(root.version) == "number" and root.version < 3

	local placements: { Placement } = {}
	local firstPlacements: { [string]: Placement } = {}

	for _, raw in json.asArray(root.placements) or {} do
		local object = json.asObject(raw)
		local id = if object then getStringField(object.id) else nil
		local node = if object then getStringField(object.node) else nil

		if object and id and node then
			local placement = {
				id = id,
				node = node,
				parentId = getStringField(object.parentId),
				position = getPosition(object.position),
			}
			table.insert(placements, placement)
			firstPlacements[node] = firstPlacements[node] or placement
		end
	end

	local nodes: { Item } = {}

	for _, raw in json.asArray(root.nodes) or {} do
		local object = json.asObject(raw)
		local id = if object then getStringField(object.id) else nil
		local kind = if object then getStringField(object.type) else nil

		if object and id and kind then
			local placement = firstPlacements[id]
			local isLegacy = placement == nil and (isBeforePlacements or object.position ~= nil)
			table.insert(nodes, {
				id = id,
				type = kind,
				position = if placement
					then { x = placement.position.x, y = placement.position.y }
					else getPosition(object.position),
				parentId = if placement
					then placement.parentId
					elseif isLegacy then getStringField(object.parentId)
					else nil,
				placement = if placement then placement.id else nil,
				unplaced = if placement == nil and not isLegacy then true else nil,
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
				browse = getStringField(source.browse),
				dir = getStringField(source.dir),
			})
		end
	end

	for _, item in nodes do
		if item.type == "task" then
			fillPullFacts(item)
		end

		-- Images from before canvases were named keep `workspace` until read.
		-- Remove at 0.1.0 with the rest of `migrations/`.
		if item.type == "image" and item.data.workspace ~= nil then
			migrateImageCanvas(item)
		end
	end

	return {
		version = 3,
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
		placements = placements,
		github = json.asObject(root.github),
		suggestions = json.asObject(root.suggestions),
		repositories = json.asObject(root.repositories),
		raw = json.object(root),
	}
end

return decodeDocObject
