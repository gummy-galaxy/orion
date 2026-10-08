local json = require("@std/json")

local mcpTypes = require("@root/cli/mcp/types")

type Field = mcpTypes.Field

-- Matches store.isValidWorkspace, written as a JSON Schema pattern.
local WORKSPACE_PATTERN = "^[a-z0-9-]+$"

local function getFieldSchema(field: Field): json.Object
	local schema: json.Object

	if field.kind == "boolean" then
		schema = json.object({ type = "boolean" })
	elseif field.kind == "int" then
		schema = json.object({ type = "integer", minimum = 1 })
	elseif field.kind == "strings" then
		schema = json.object({
			type = "array",
			items = json.object({ type = "string", minLength = 1 }),
			minItems = 1,
		})
	elseif field.kind == "enum" then
		local values: json.Array = {}

		for _, value in field.values or {} do
			table.insert(values, value)
		end

		schema = json.object({ type = "string", enum = values })
	elseif field.kind == "workspace" then
		schema = json.object({ type = "string", pattern = WORKSPACE_PATTERN })
	else
		schema = json.object({ type = "string" })

		if field.minLength or field.kind == "id" then
			schema.minLength = field.minLength or 1
		end
	end

	if field.description then
		schema.description = field.description
	end

	return schema
end

return getFieldSchema
