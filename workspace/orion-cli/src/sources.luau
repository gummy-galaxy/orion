local json = require("@std/json")

local types = require("@root/types")

type Source = types.Source

-- Each source as JSON, with the command this machine runs for it from
-- `commands`, by source id.
local function getJson(values: { Source }, commands: { [string]: { string } }): json.Array
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
		value.command, value.browse, value.dir = getStringArray(commands[source.id]), source.browse, source.dir
		table.insert(result, value)
	end

	return result
end

return getJson
