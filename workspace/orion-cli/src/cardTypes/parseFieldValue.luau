local json = require("@std/json")

local cardTypes = require("@root/cardTypes/types")

type Field = cardTypes.Field

local DATE = "^%d%d%d%d%-%d%d%-%d%d$"

-- A field's value from the text a person or agent typed, checked against the
-- field's kind. Empty text clears it.
local function parseFieldValue(field: Field, text: string): json.Value
	if text == "" then
		return nil
	end

	if field.kind == "number" then
		local number = tonumber(text)
		assert(number and number == number and math.abs(number) ~= math.huge, `{field.name} must be a number`)
		return number
	elseif field.kind == "boolean" then
		assert(text == "true" or text == "false", `{field.name} must be true or false`)
		return text == "true"
	elseif field.kind == "choice" then
		local names: { string } = {}

		for _, choice in field.choices or {} do
			if choice.value == text then
				return text
			end

			table.insert(names, choice.value)
		end

		error(`{field.name} must be one of {table.concat(names, ", ")}`)
	elseif field.kind == "date" then
		assert(text:match(DATE), `{field.name} must be a date such as 2026-10-26`)
	elseif field.kind == "url" then
		assert(text:match("^https?://[^%s]+$"), `{field.name} must be an http or https URL`)
	end

	return text
end

return parseFieldValue
