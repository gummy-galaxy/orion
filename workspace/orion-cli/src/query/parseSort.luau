local querySyntax = require("@root/query/querySyntax")
local queryTypes = require("@root/query/types")

type Sort = queryTypes.Sort

-- Reads a sort such as `status,-label`: query fields separated by commas, each
-- descending when it starts with `-`.
local function parseSort(input: string): { Sort }
	local keys: { Sort } = {}

	for part in (input .. ","):gmatch("([^,]*),") do
		local trimmed = part:match("^%s*(.-)%s*$") :: string
		local isDescending = trimmed:sub(1, 1) == "-"
		local field = if isDescending then trimmed:sub(2) else trimmed

		if field == "" then
			error("sort: expected a field, such as `label` or `-status`", 0)
		end

		if not querySyntax.fieldsByName[field] then
			error(`sort: unknown field '{field}'`, 0)
		end

		table.insert(keys, { field = field, isDescending = isDescending })
	end

	return keys
end

return parseSort
