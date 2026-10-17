local json = require("@std/json")

local checkThemeValue = require("@root/themes/checkThemeValue")
local tokenContract = require("@root/themes/tokenContract")

export type ThemeCheck = {
	label: string,
	schemes: { string },
	-- Problems that did not stop the theme, such as tokens it does not name.
	notes: { string },
	-- Why the file cannot be used. Nil when it can.
	error: string?,
}

local SCHEMES = { "light", "dark" }
local MAX_LABEL_LENGTH = 40

local function fileLabel(file: string): string
	return (file:gsub("%.json$", ""))
end

local function broken(file: string, reason: string): ThemeCheck
	return { label = fileLabel(file), schemes = {}, notes = {}, error = reason }
end

-- The string keys of an object in sorted order, so the same file always reports the same problem first.
local function sortedKeys(object: json.Object): { string }
	local keys: { string } = {}

	for key in pairs(object) do
		if type(key) == "string" then
			table.insert(keys, key)
		end
	end

	table.sort(keys)

	return keys
end

-- Checks a theme file's text the way the app reads it: JSON with a light or dark object of token values.
-- Unknown tokens are noted and skipped. Any other problem makes the file unusable.
local function checkThemeFile(file: string, text: string): ThemeCheck
	local didParse, data = pcall(json.deserialize, text)

	if not didParse or data == nil then
		return broken(file, "is not valid JSON")
	end

	local object = json.asObject(data :: json.Value)

	if not object then
		return broken(file, "must be a JSON object")
	end

	local name = object.name
	local trimmed = if type(name) == "string" then name:match("^%s*(.-)%s*$") or "" else ""
	local label = if trimmed ~= "" then trimmed:sub(1, MAX_LABEL_LENGTH) else fileLabel(file)

	local notes: { string } = {}
	local schemes: { string } = {}

	for _, scheme in SCHEMES do
		local source = object[scheme]

		if source == nil then
			continue
		end

		local variant = json.asObject(source :: json.Value)

		if not variant then
			return broken(file, `"{scheme}" must be an object of token values`)
		end

		for _, key in sortedKeys(variant) do
			local value = variant[key]
			local token = tokenContract[key]

			if not token then
				table.insert(notes, `Ignored unknown token {key} in {scheme}`)
			elseif type(value) ~= "string" then
				return broken(file, `{scheme} {key} must be a string`)
			else
				local problem = checkThemeValue(token.group, value)

				if problem then
					return broken(file, `{scheme} {key} {problem}`)
				end
			end
		end

		table.insert(schemes, scheme)
	end

	if #schemes == 0 then
		return broken(file, 'needs a "light" or "dark" object of token values')
	end

	return { label = label, schemes = schemes, notes = notes }
end

return checkThemeFile
