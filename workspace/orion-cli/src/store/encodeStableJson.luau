local json = require("@std/json")

local INDENT = "  "

-- Tells objects from arrays the way `json.serialize` does, so a plain table
-- with string keys stays an object.
local function isObject(value: { [unknown]: unknown }): boolean
	return #value == 0 and next(value) ~= nil
end

local function encode(value: json.Value, depth: number): string
	if type(value) == "table" and isObject(value :: { [unknown]: unknown }) then
		local object = value :: json.Object
		local keys: { string } = {}

		for key in object do
			if type(key) == "string" then
				table.insert(keys, key)
			end
		end

		if #keys == 0 then
			return "{}"
		end

		table.sort(keys)

		local inner = string.rep(INDENT, depth + 1)
		local entries: { string } = {}

		for _, key in keys do
			table.insert(entries, `{inner}{json.serialize(key)}: {encode(object[key], depth + 1)}`)
		end

		return `\{\n{table.concat(entries, ",\n")}\n{string.rep(INDENT, depth)}}`
	end

	if type(value) == "table" then
		local array = value :: json.Array

		if #array == 0 then
			return "[]"
		end

		local inner = string.rep(INDENT, depth + 1)
		local entries: { string } = {}

		for _, entry in array do
			table.insert(entries, `{inner}{encode(entry, depth + 1)}`)
		end

		return `[\n{table.concat(entries, ",\n")}\n{string.rep(INDENT, depth)}]`
	end

	return json.serialize(value)
end

-- JSON text with sorted keys, two-space indents, and a final newline, so the
-- same value always writes the same bytes and a change to one field shows as
-- one line in a diff.
local function encodeStableJson(value: json.Value): string
	return `{encode(value, 0)}\n`
end

return encodeStableJson
