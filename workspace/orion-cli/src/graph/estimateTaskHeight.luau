local geometry = require("@root/geometry")
local types = require("@root/types")

type Item = types.Item
type TextStyle = { read size: number, read lineHeight: number }

local text = geometry.CARD_TEXT

local function measure(value: string, style: TextStyle): number
	return (utf8.len(value) or #value) * style.size * text.characterWidth
end

-- How many lines `value` wraps to at `width`, breaking between words and at
-- newlines as the app's cards do.
local function countLines(value: string, style: TextStyle, width: number): number
	local lines = 0

	for _, paragraph in value:split("\n") do
		local line = ""
		lines += 1

		for word in paragraph:gmatch("%S+") do
			local nextLine = if line == "" then word else `{line} {word}`

			if line == "" or measure(nextLine, style) <= width then
				line = nextLine
				continue
			end

			lines += 1
			line = word
		end

		-- A word too long for one line breaks anywhere, as the card's
		-- `overflow-wrap: anywhere` lets it.
		lines += math.max(0, math.ceil(measure(line, style) / width) - 1)
	end

	return lines
end

local function getText(item: Item, field: string, fallback: string): string
	local value = item.data[field]
	return if type(value) == "string" and value ~= "" then value else fallback
end

--[[
	About how tall the app draws a card in the classic skin. Notes grow to show
	all their text and components size to theirs, up to a limit; work cards keep
	the card height. The app measures text with the browser's fonts, and this
	estimates it from the same geometry, so a stored height the app measured is
	closer when there is one.
]]
local function estimateTaskHeight(item: Item): number
	local itemKind = item.data.itemKind
	local height

	if itemKind == "note" then
		local lines = countLines(getText(item, "label", "Empty note"), text.note, geometry.TASK_WIDTH - text.sides.note)
		height = text.chrome + lines * text.note.size * text.note.lineHeight
	elseif itemKind == "component" then
		local shape = item.data.shape
		local room = if type(shape) == "string" then (text.shapeRoom :: any)[shape] else nil
		room = room or { x = 0, y = 0 }
		local width = geometry.TASK_WIDTH - text.sides.component - room.x
		local label = countLines(getText(item, "label", "Untitled component"), text.label, width)
			* text.label.size
			* text.label.lineHeight
		local note = item.data.note
		local description = if type(note) == "string" and note ~= ""
			then text.descriptionGap
				+ countLines(note, text.description, width) * text.description.size * text.description.lineHeight
			else 0

		height = text.chrome + room.y + label + description
	else
		return geometry.TASK_HEIGHT
	end

	local rounded = math.ceil((height + text.slack) / text.step) * text.step
	return math.clamp(rounded, geometry.TASK_HEIGHT, geometry.TASK_MAX_HEIGHT)
end

return estimateTaskHeight
