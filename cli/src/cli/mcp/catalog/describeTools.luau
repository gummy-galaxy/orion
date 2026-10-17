local json = require("@std/json")

local mcpTypes = require("@root/cli/mcp/types")
local tools = require("@root/cli/mcp/tools")

type Field = mcpTypes.Field

-- Matches store.isValidWorkspace, written as a JSON Schema pattern.
local WORKSPACE_PATTERN = "^[a-z0-9-]+$"

local function getFieldSchema(field: Field): json.Object
	local schema: json.Object

	if field.kind == "boolean" then
		schema = json.object({ type = "boolean" })
	elseif field.kind == "int" then
		schema = json.object({ type = "integer", minimum = field.minimum or 1 })
	elseif field.kind == "strings" then
		schema = json.object({
			type = "array",
			items = json.object({ type = "string", minLength = 1 }),
			minItems = 1,
		})
	elseif field.kind == "operations" then
		schema = json.object({
			type = "array",
			items = json.object({ type = "object" }),
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

-- Lists every tool in the shape MCP's tools/list expects.
local function describeTools(): json.Array
	local descriptions: json.Array = {}

	for _, tool in tools do
		local properties: { [string]: json.Value } = {}
		local required: json.Array = {}

		for _, field in tool.fields do
			properties[field.name] = getFieldSchema(field)

			if field.required then
				table.insert(required, field.name)
			end
		end

		local inputSchema = json.object({
			type = "object",
			properties = json.object(properties),
			additionalProperties = false,
		})

		if #required > 0 then
			inputSchema.required = required
		end

		local description = json.object({
			name = tool.name,
			description = tool.description,
			inputSchema = inputSchema,
		})

		if tool.annotations then
			local annotations: { [string]: json.Value } = {}

			for key, value in tool.annotations do
				annotations[key] = value
			end

			description.annotations = json.object(annotations)
		end

		table.insert(descriptions, description)
	end

	return descriptions
end

return describeTools
