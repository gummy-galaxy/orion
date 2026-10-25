local json = require("@std/json")

local findItem = require("@root/graph/findItem")
local getAncestors = require("@root/graph/getAncestors")
local getLabel = require("@root/graph/getLabel")
local graphTypes = require("@root/graph/types")
local isGroup = require("@root/graph/isGroup")
local pad = require("@root/render/pad")
local renderGroup = require("@root/render/group")
local renderItem = require("@root/render")
local types = require("@root/types")

type Doc = types.Doc
type Focus = types.Focus
type Item = types.Item

local focus = {}

-- Ids the app reported that are still on the canvas; the app can be a moment behind the file.
local function findSelectedItems(doc: Doc, report: Focus): { Item }
	local items = {}
	for _, id in report.selected do
		local item = findItem(doc, id)
		if item then
			table.insert(items, item)
		end
	end
	return items
end

local function findOpenGroup(doc: Doc, report: Focus): Item?
	local item = if report.open then findItem(doc, report.open) else nil
	return if item and isGroup(item) then item else nil
end

-- The open group's ancestors, outermost first.
local function findAncestorTrail(doc: Doc, group: Item): { Item }
	local ancestors = {}
	for _, id in getAncestors(doc, group.id) do
		local parent = findItem(doc, id)
		if parent then
			table.insert(ancestors, 1, parent)
		end
	end
	return ancestors
end

function focus.serialize(doc: Doc, derived: graphTypes.Derived, report: Focus?): json.Object
	local object: json.Object = json.object({ appOpen = report ~= nil })
	local selected: json.Array = {}
	object.selected = selected
	if not report then
		return object
	end
	object.updatedAt = report.updatedAt
	local group = findOpenGroup(doc, report)
	if group then
		local open = renderGroup.serialize(derived, group)
		local path: json.Array = {}
		for _, parent in findAncestorTrail(doc, group) do
			table.insert(path, json.object({ id = parent.id, label = getLabel(parent) }))
		end
		open.path = path
		object.open = open
	end
	for _, item in findSelectedItems(doc, report) do
		table.insert(selected, renderItem.itemJson(doc, derived, item))
	end
	return object
end

function focus.format(doc: Doc, derived: graphTypes.Derived, report: Focus?): string
	if not report then
		return "The Orion app isn't open, so nothing is in focus."
	end
	local lines = {}
	local group = findOpenGroup(doc, report)
	if group then
		local within = {}
		for _, parent in findAncestorTrail(doc, group) do
			table.insert(within, getLabel(parent))
		end
		local inside = if #within > 0 then `, inside {table.concat(within, " › ")}` else ""
		table.insert(lines, `Open: {group.id}  {renderGroup.formatLine(derived, group)}{inside}`)
	else
		table.insert(lines, "Open: the top level")
	end
	local items = findSelectedItems(doc, report)
	if #items == 0 then
		table.insert(lines, "Nothing selected.")
	else
		table.insert(lines, "Selected:")
		for _, item in items do
			if isGroup(item) then
				table.insert(lines, `  {pad("group", 9)}{pad(item.id, 38)}{renderGroup.formatLine(derived, item)}`)
			else
				table.insert(lines, `  {renderItem.table(doc, derived, { item })}`)
			end
		end
	end
	if report.updatedAt then
		table.insert(lines, `As of {report.updatedAt}`)
	end
	return table.concat(lines, "\n")
end

return table.freeze(focus)
