local json = require("@std/json")

local getFieldSchema = require("@root/cli/mcp/catalog/getFieldSchema")
local tools = require("@root/cli/mcp/tools")

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
