local checkFields = require("@root/canvas/items/checkFields")
local getHeaderHeight = require("@root/canvas/groups/getHeaderHeight")
local getItem = require("@root/canvas/items/getItem")
local graphTypes = require("@root/canvas/types")
local isComponent = require("@root/canvas/items/isComponent")
local isGroup = require("@root/canvas/groups/isGroup")
local isNote = require("@root/canvas/items/isNote")
local setFieldValue = require("@root/canvas/items/setFieldValue")
local setLook = require("@root/canvas/items/setLook")
local snooze = require("@root/canvas/items/snooze")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type ItemFields = graphTypes.ItemFields

-- Adding or removing a group's header moves its top edge up or down and keeps
-- every card where it is on the canvas, as the app does when it refits a group.
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
				and fields.snoozedUntil == nil
				and fields.values == nil,
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

	local drawn = { item.data.label, item.data.note, item.data.type, item.data.shape }

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

	-- As with add, giving a card a shape makes it a component. Giving a note
	-- a kind makes it a work item. A step is what a card is when nobody chose,
	-- so it lets the card's sources and repository decide again.
	local givenKind = fields.kind
		or (if fields.shape and fields.shape ~= "" and not isNote(item) then "component" else nil)

	if givenKind then
		item.data.type = if givenKind == "step" then nil else givenKind
	end

	-- Work isn't drawn with a shape or tint, so a component turned into work
	-- drops them.
	if not isComponent(item) then
		item.data.shape = nil
		item.data.color = nil
	end

	if fields.snoozedUntil then
		snooze(doc, id, if fields.snoozedUntil == "" then nil else fields.snoozedUntil)
	end

	-- After the kind, so a field the new kind declares can be set with it.
	for name, text in fields.values or {} do
		setFieldValue(doc, id, name, text)
	end

	setLook(item, fields)

	-- A height the app measured no longer fits new text or a new shape, so the
	-- estimate stands in until it measures again.
	local now = { item.data.label, item.data.note, item.data.type, item.data.shape }

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
