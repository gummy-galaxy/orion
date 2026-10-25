local checkFields = require("@root/graph/checkFields")
local chooseItemKind = require("@root/graph/chooseItemKind")
local findRef = require("@root/refs/findRef")
local getHeaderHeight = require("@root/graph/getHeaderHeight")
local getItem = require("@root/graph/getItem")
local getStringField = require("@root/getStringField")
local graphTypes = require("@root/graph/types")
local isComponent = require("@root/graph/isComponent")
local isGate = require("@root/graph/isGate")
local isGroup = require("@root/graph/isGroup")
local isNote = require("@root/graph/isNote")
local setLook = require("@root/graph/setLook")
local snooze = require("@root/graph/snooze")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type ItemFields = graphTypes.ItemFields

-- Adding or removing a group's header moves its top edge up or down and keeps every card where it is on the canvas,
-- as the app does when it refits a group.
local function resizeHeader(doc: Doc, group: Item, delta: number)
	if delta == 0 then
		return
	end

	group.position = { x = group.position.x, y = group.position.y - delta }

	if group.height then
		group.height = (group.height :: number) + delta
	end

	for _, item in doc.nodes do
		if item.parentId == group.id then
			item.position = { x = item.position.x, y = item.position.y + delta }
		end
	end
end

local function setFields(doc: Doc, id: string, fields: ItemFields): Item
	local item = getItem(doc, id)
	checkFields(fields)

	if isGroup(item) then
		assert(
			fields.status == nil
				and fields.repo == nil
				and fields.who == nil
				and fields.note == nil
				and fields.kind == nil
				and fields.shape == nil
				and fields.snoozedUntil == nil,
			"groups only take a label, blurb, arrange, cover, background, header, and color"
		)

		if fields.color then
			item.data.color = if fields.color == "" then nil else fields.color
		end

		if fields.label then
			item.data.label = fields.label
		end

		if fields.blurb then
			item.data.blurb = if fields.blurb == "" then nil else fields.blurb
		end

		if fields.arrange then
			item.data.arrange = if fields.arrange == "auto" then nil else fields.arrange

			if fields.arrange ~= "custom" and item.data.layout == nil then
				item.data.layout = "refit"
			end
		end

		if fields.cover then
			item.data.cover = if fields.cover == "" then nil else fields.cover
		end

		if fields.background then
			item.data.background = if fields.background == "" then nil else fields.background
		end

		if fields.header then
			local before = getHeaderHeight(item)
			item.data.header = if fields.header == "" then nil else fields.header
			resizeHeader(doc, item, getHeaderHeight(item) - before)
		end

		return item
	end

	assert(fields.arrange == nil, `"{id}" is an item; only groups take an arrangement`)
	assert(fields.blurb == nil, `"{id}" is an item; only groups take a blurb`)
	assert(
		fields.cover == nil and fields.background == nil and fields.header == nil,
		`"{id}" is an item; only groups take a cover, background, or header`
	)

	local drawn = { item.data.label, item.data.note, item.data.itemKind, item.data.shape }

	if fields.label then
		item.data.label = fields.label
	end

	if fields.status then
		item.data.status = fields.status
		item.data.deferredByClosedPull = nil
	end

	if fields.who then
		item.data.who = if fields.who == "" then nil else fields.who
	end

	if fields.note then
		item.data.note = if fields.note == "" then nil else fields.note
	end

	if fields.repo then
		item.data.repo = if fields.repo == "" then nil else fields.repo
	end

	-- Giving a note a kind makes it a work item.
	if fields.kind and isNote(item) then
		item.data.itemKind = "step"
	end

	-- As with add, giving a card a shape makes it a component.
	local givenKind = fields.kind
		or (if fields.shape and fields.shape ~= "" and not isNote(item) then "component" else nil)

	if not isNote(item) and (fields.repo or givenKind) then
		local repo = getStringField(item.data.repo)
		local pr = findRef(item, "pull")
		local kind = givenKind
			or (if isGate(item) or isComponent(item) then getStringField(item.data.itemKind) else nil)
		item.data.itemKind = chooseItemKind(repo, if pr then 1 else nil, kind)
	end

	-- Work isn't drawn with a shape or tint, so a component turned into work drops them.
	if not isComponent(item) then
		item.data.shape = nil
		item.data.color = nil
	end

	if fields.snoozedUntil then
		snooze(doc, id, if fields.snoozedUntil == "" then nil else fields.snoozedUntil)
	end

	setLook(item, fields)

	-- A height the app measured no longer fits new text or a new shape, so the estimate stands in until it measures again.
	local now = { item.data.label, item.data.note, item.data.itemKind, item.data.shape }

	-- Fields can be nil, so walk them by index.
	for i = 1, 4 do
		if now[i] ~= drawn[i] then
			item.width = nil
			item.height = nil
			break
		end
	end

	return item
end

return setFields
