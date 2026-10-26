local tokenContract = require("@root/themes/tokenContract")

-- Functions a color may call. url(), image-set(), expression(), and the rest
-- are not on the list.
local COLOR_FUNCTIONS = { "rgb", "rgba", "hsl", "hsla", "hwb", "oklab", "oklch", "color-mix", "var" }
local EASING_KEYWORDS = { "ease", "ease-in", "ease-out", "ease-in-out", "linear" }
local LENGTH_UNITS = { "px", "rem", "em" }
local RADIUS_UNITS = { "px", "rem", "em", "%" }
-- Longer than any transition should run, so a typo can't freeze the interface
-- for minutes.
local MAX_DURATION_MS = 10000
-- Radii may be a percentage, so they are checked against a larger number than
-- sizes and spacing.
local MAX_RADIUS = 1000
-- A bare line height multiplies the font size, so anything past this is a typo.
local MAX_LINE_HEIGHT = 10
local MAX_VALUE_LENGTH = 200

local cssVars: { [string]: boolean } = {}
for _, token in pairs(tokenContract) do
	cssVars[token.cssVar] = true
end

local function trim(text: string): string
	return text:match("^%s*(.-)%s*$") or ""
end

-- A whole number or a decimal with digits on both sides of the point.
local function numberOf(text: string): number?
	if text:match("^%d+$") or text:match("^%d+%.%d+$") then
		return tonumber(text)
	end

	return nil
end

-- A length is a number followed by one of the units. Zero may stand alone when
-- bare is allowed.
local function isLength(text: string, units: { string }, bare: boolean, limit: number): boolean
	if bare and text == "0" then
		return true
	end

	for _, unit in units do
		if text:sub(-#unit) == unit then
			local value = numberOf(text:sub(1, #text - #unit))

			return value ~= nil and value <= limit
		end
	end

	return false
end

local function isBalanced(text: string): boolean
	local depth = 0

	for character in text:gmatch(".") do
		if character == "(" then
			depth += 1
		elseif character == ")" then
			depth -= 1
		end

		if depth < 0 then
			return false
		end
	end

	return depth == 0
end

local function checkColor(text: string): string?
	if not isBalanced(text) then
		return "has unbalanced parentheses"
	end

	local lower = text:lower()

	for name in lower:gmatch("([%a%-]+)%(") do
		if not table.find(COLOR_FUNCTIONS, name) then
			return `uses {name}(), which a color cannot`
		end
	end

	local references = 0

	for name in lower:gmatch("var%(%s*(%-%-[%w%-]+)%s*%)") do
		references += 1

		if not cssVars[name] then
			return "refers to a variable this theme cannot name"
		end
	end

	local calls = 0

	for _ in lower:gmatch("var%(") do
		calls += 1
	end

	if calls ~= references then
		return "refers to a variable this theme cannot name"
	end

	if not text:match("^[%w #%%%.,()%+%-/]+$") then
		return "has characters that are not part of a color"
	end

	return nil
end

local function checkShadow(text: string): string?
	if text == "none" then
		return nil
	end

	local problem = checkColor(text)

	if problem then
		return (problem:gsub("part of a color", "part of a shadow"))
	end

	return nil
end

local function checkFont(text: string): string?
	if not text:match("^[%w ,'\"_%-]+$") then
		return "has characters that are not part of a font name"
	end

	local singles = select(2, text:gsub("'", ""))
	local doubles = select(2, text:gsub('"', ""))

	if singles % 2 ~= 0 or doubles % 2 ~= 0 then
		return "has unbalanced quotes"
	end

	return nil
end

local function checkDuration(text: string): string?
	local unit = if text:sub(-2) == "ms" then "ms" elseif text:sub(-1) == "s" then "s" else nil
	local value = if unit then numberOf(text:sub(1, #text - #unit)) else nil

	if value == nil then
		return "must be a time in ms or s"
	end

	local milliseconds = if unit == "s" then value * 1000 else value

	if milliseconds > MAX_DURATION_MS then
		return "must be 10s or less"
	end

	return nil
end

local function checkCubicBezier(text: string): boolean
	local inside = text:match("^cubic%-bezier%((.*)%)$")

	if not inside then
		return false
	end

	local count = 0

	for piece in (inside .. ","):gmatch("([^,]*),") do
		local unsigned = (trim(piece):gsub("^%-", ""))

		if numberOf(unsigned) == nil then
			return false
		end

		count += 1
	end

	return count == 4
end

-- Checks one value against its token's group. Returns the problem, or nil when
-- the value is plain CSS for that group.
local function checkThemeValue(group: string, value: string): string?
	local text = trim(value)

	if text == "" then
		return "is empty"
	end

	if #text > MAX_VALUE_LENGTH then
		return "is too long"
	end

	if group == "color" or group == "status" then
		return checkColor(text)
	elseif group == "font" then
		return checkFont(text)
	elseif group == "weight" then
		local weight = if text:match("^%d+$") then tonumber(text) else nil

		if weight and weight >= 100 and weight <= 1000 then
			return nil
		end

		return "must be a weight from 100 to 1000"
	elseif group == "size" or group == "space" or group == "border" then
		if isLength(text, LENGTH_UNITS, true, MAX_VALUE_LENGTH) then
			return nil
		end

		return "must be a length in px, rem, or em"
	elseif group == "line-height" then
		local lineHeight = numberOf(text)

		if (lineHeight and lineHeight <= MAX_LINE_HEIGHT) or isLength(text, LENGTH_UNITS, true, MAX_VALUE_LENGTH) then
			return nil
		end

		return "must be a number, such as 1.4, or a length in px, rem, or em"
	elseif group == "radius" then
		local parts: { string } = {}

		for part in text:gmatch("[^ ]+") do
			table.insert(parts, part)
		end

		-- Joining the parts gives the text back only when they were separated
		-- by single spaces.
		local valid = #parts >= 1 and #parts <= 4 and table.concat(parts, " ") == text

		for _, part in parts do
			valid = valid and isLength(part, RADIUS_UNITS, true, MAX_RADIUS)
		end

		if valid then
			return nil
		end

		return "must be one to four lengths in px, rem, em, or %"
	elseif group == "shadow" then
		return checkShadow(text)
	elseif group == "duration" then
		return checkDuration(text)
	elseif group == "easing" then
		if table.find(EASING_KEYWORDS, text) or checkCubicBezier(text) then
			return nil
		end

		return "must be an easing keyword or cubic-bezier()"
	end

	return `has a group the CLI does not know: {group}`
end

return checkThemeValue
