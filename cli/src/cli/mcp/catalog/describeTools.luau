local json = require("@std/json")

local mcpTypes = require("@root/cli/mcp/types")

type Field = mcpTypes.Field
type Tool = mcpTypes.Tool

-- Matches `isValidWorkspace`, written as a JSON Schema pattern.
local CANVAS_PATTERN = "^[a-z0-9-]+$"

local function getFieldSchema(field: Field): json.Object
	local schema: json.Object

	if field.type == "boolean" then
		schema = json.object({ type = "boolean" })
	elseif field.type == "integer" then
		schema = json.object({ type = "integer", minimum = field.minimum or 1 })
	elseif field.type == "list" or field.type == "commaList" or field.type == "command" then
		schema = json.object({
			type = "array",
			items = json.object({ type = "string", minLength = 1 }),
			minItems = 1,
		})
	elseif field.type == "jsonList" then
		schema = json.object({
			type = "array",
			items = json.object({ type = "object" }),
			minItems = 1,
		})
	elseif field.type == "enum" then
		local values: json.Array = {}

		for _, value in field.values or {} do
			table.insert(values, value)
		end

		schema = json.object({ type = "string", enum = values })
	elseif field.type == "canvas" then
		schema = json.object({ type = "string", pattern = CANVAS_PATTERN })
	else
		schema = json.object({ type = "string" })

		if field.required or field.type == "id" then
			schema.minLength = 1
		end
	end

	if field.description then
		schema.description = field.description
	end

	return schema
end

-- Lists every tool in the shape MCP's tools/list expects.
local function describeTools(tools: { Tool }): json.Array
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

			for key, value in tool.annotations :: { [string]: boolean } do
				annotations[key] = value
			end

			description.annotations = json.object(annotations)
		end

		table.insert(descriptions, description)
	end

	return descriptions
end

return describeTools
