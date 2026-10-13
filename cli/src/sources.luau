local json = require("@std/json")

local types = require("@root/types")

type Source = types.Source

local function getJson(values: { Source }): json.Array
	local function getStringArray(strings: { string }?): json.Array?
		if not strings then
			return nil
		end

		local result: json.Array = {}

		for _, entry in strings do
			table.insert(result, entry)
		end

		return result
	end

	local result: json.Array = {}

	for _, source in values do
		local value = json.object({ id = source.id, kind = source.kind })
		value.host, value.owners, value.include, value.exclude =
			source.host, getStringArray(source.owners), getStringArray(source.include), getStringArray(source.exclude)
		value.command, value.browse = getStringArray(source.command), source.browse
		table.insert(result, value)
	end

	return result
end

return getJson
