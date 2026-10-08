local json = require("@std/json")

local mcpTypes = require("@root/cli/mcp/types")

type Field = mcpTypes.Field

local function checkValue(field: Field, value: json.Value)
	local name = field.name

	if field.kind == "boolean" then
		assert(type(value) == "boolean", `{name} must be a boolean`)
	elseif field.kind == "int" then
		assert(
			type(value) == "number" and value >= 1 and value == math.floor(value),
			`{name} must be a positive integer`
		)
	elseif field.kind == "strings" then
		local list = json.asArray(value)
		assert(list, `{name} must be a list of strings`)

		for _, entry in list do
			assert(type(entry) == "string" and entry ~= "", `{name} must be a list of strings`)
		end
	elseif field.kind == "enum" then
		local values = field.values or {}
		assert(
			type(value) == "string" and table.find(values, value),
			`{name} must be one of: {table.concat(values, ", ")}`
		)
	else
		assert(type(value) == "string", `{name} must be a string`)
		assert(#value >= (field.minLength or if field.kind == "id" then 1 else 0), `{name} must not be empty`)
	end
end

return checkValue
