local checkBackground = require("@root/canvas/appearance/checkBackground")
local checkHeader = require("@root/canvas/appearance/checkHeader")
local fieldValues = require("@root/fieldValues")
local graphTypes = require("@root/canvas/types")
local isAssetId = require("@root/storage/media/isAssetId")

type ItemFields = graphTypes.ItemFields

-- Refuses any field value Orion doesn't store, before an edit writes it.
local function checkFields(fields: ItemFields)
	assert(
		fields.repo == nil or fields.repo == "" or fields.repo:match("^[%w_.%-]+/[%w_.%-]+$"),
		"repo must be owner/name"
	)
	assert(
		fields.status == nil or table.find(fieldValues.statuses, fields.status),
		`status must be one of {table.concat(fieldValues.statuses, ", ")}`
	)
	assert(
		fields.who == nil or fields.who == "" or table.find(fieldValues.who, fields.who),
		`who must be one of {table.concat(fieldValues.who, ", ")}`
	)
	assert(
		fields.kind == nil or table.find(fieldValues.kinds, fields.kind),
		`kind must be one of {table.concat(fieldValues.kinds, ", ")}`
	)
	assert(
		fields.arrange == nil or table.find(fieldValues.arrangements, fields.arrange),
		`arrange must be one of {table.concat(fieldValues.arrangements, ", ")}`
	)
	assert(
		fields.shape == nil or fields.shape == "" or table.find(fieldValues.shapes, fields.shape),
		`shape must be one of {table.concat(fieldValues.shapes, ", ")}`
	)
	assert(
		fields.color == nil or fields.color == "" or table.find(fieldValues.colors, fields.color),
		`color must be one of {table.concat(fieldValues.colors, ", ")}`
	)
	assert(
		fields.cover == nil or fields.cover == "" or isAssetId(fields.cover),
		"cover must be an image asset id, such as the asset from orion media add"
	)

	if fields.background and fields.background ~= "" then
		checkBackground(fields.background)
	end

	if fields.header and fields.header ~= "" then
		checkHeader(fields.header)
	end

	assert(
		fields.snoozedUntil == nil
			or fields.snoozedUntil == ""
			or fields.snoozedUntil:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"),
		"snoozedUntil must be a UTC time such as 2026-10-12T17:00:00Z"
	)
end

return checkFields
