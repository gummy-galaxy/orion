local getRefs = require("@root/canvas/refs/getRefs")
local linkKey = require("@root/canvas/operations/linkKey")
local operationTypes = require("@root/canvas/operations/types")
local sameValue = require("@root/canvas/operations/sameValue")
local types = require("@root/types")

type Changes = operationTypes.Changes
type Doc = types.Doc
type Item = types.Item
type RefChange = operationTypes.RefChange
type Snapshot = operationTypes.Snapshot

local function refKey(ref: types.Ref): string
	return `{ref.source}\0{ref.kind}\0{ref.key:lower()}`
end

-- Adds each ref `from` has and `to` doesn't to `list`.
local function addMissingRefs(list: { RefChange }, id: string, from: Item?, to: Item?)
	if from == nil then
		return
	end

	local kept: { [string]: boolean } = {}

	for _, ref in if to then getRefs(to) else {} do
		kept[refKey(ref)] = true
	end

	for _, ref in getRefs(from) do
		if not kept[refKey(ref)] then
			table.insert(list, { id = id, source = ref.source, kind = ref.kind, key = ref.key })
		end
	end
end

-- Compares the document with a snapshot taken before an edit, and lists what
-- the edit changed in document order.
local function getChanges(before: Snapshot, doc: Doc): Changes
	local changes: Changes = {
		added = {},
		changed = {},
		removed = {},
		linked = {},
		relinked = {},
		unlinked = {},
		attached = {},
		detached = {},
	}
	local current: { [string]: boolean } = {}

	for _, item in doc.nodes do
		local saved = before.nodes[item.id]
		local previous = if saved then saved.item else nil
		current[item.id] = true

		if previous == nil then
			table.insert(changes.added, item.id)
		elseif not sameValue(previous, item) then
			table.insert(changes.changed, item.id)
		end

		addMissingRefs(changes.attached, item.id, item, previous)
		addMissingRefs(changes.detached, item.id, previous, item)
	end

	local removed: { { index: number, id: string } } = {}

	for id, saved in before.nodes do
		if not current[id] then
			table.insert(removed, { index = saved.index, id = id })
		end
	end

	table.sort(removed, function(a: { index: number }, b: { index: number }): boolean
		return a.index < b.index
	end)

	for _, entry in removed do
		table.insert(changes.removed, entry.id)
	end

	local currentLinks: { [string]: boolean } = {}

	for _, link in doc.links do
		local key = linkKey(link.from, link.to)
		local saved = before.links[key]
		currentLinks[key] = true

		if saved == nil then
			table.insert(changes.linked, link)
		elseif saved.link.kind ~= link.kind or saved.link.label ~= link.label then
			table.insert(changes.relinked, link)
		end
	end

	local unlinked: { { index: number, link: types.Link } } = {}

	for key, saved in before.links do
		if not currentLinks[key] then
			table.insert(unlinked, saved)
		end
	end

	table.sort(unlinked, function(a: { index: number }, b: { index: number }): boolean
		return a.index < b.index
	end)

	for _, entry in unlinked do
		table.insert(changes.unlinked, entry.link)
	end

	return changes
end

return getChanges
