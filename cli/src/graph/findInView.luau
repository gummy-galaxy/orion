local findItem = require("@root/graph/findItem")
local getContents = require("@root/graph/getContents")
local isGroup = require("@root/graph/isGroup")
local types = require("@root/types")

type Doc = types.Doc
type Focus = types.Focus

--[[
	The ids of what the app is showing: the open group and everything inside it, the selection and anything inside a
	selected group, and whatever blocks one of those across a single link. A selection counts without an open group, so
	selected cards at the top level are in view too. Ids the app reported that are no longer on the canvas are skipped.
]]
local function findInView(doc: Doc, focus: Focus?): { [string]: boolean }
	local shown: { [string]: boolean } = {}

	if not focus then
		return shown
	end

	local function show(id: string)
		local item = findItem(doc, id)

		if not item then
			return
		end

		shown[id] = true

		if isGroup(item) then
			for _, child in getContents(doc, id) do
				shown[child.id] = true
			end
		end
	end

	local open = if focus.open then findItem(doc, focus.open) else nil

	if open and isGroup(open) then
		show(open.id)
	end

	for _, id in focus.selected do
		show(id)
	end

	local inView = table.clone(shown)

	for _, link in doc.links do
		if link.kind == "blocks" and shown[link.to] then
			inView[link.from] = true
		end
	end

	return inView
end

return findInView
