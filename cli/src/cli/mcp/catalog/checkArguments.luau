local json = require("@std/json")

local checkValue = require("@root/cli/mcp/catalog/checkValue")
local isAbsent = require("@root/cli/mcp/catalog/isAbsent")
local mcpTypes = require("@root/cli/mcp/types")

type Field = mcpTypes.Field
type Tool = mcpTypes.Tool

local function checkArguments(tool: Tool, arguments: json.Object)
	local fields: { [string]: Field } = {}

	for _, field in tool.fields do
		fields[field.name] = field
	end

	for key, value in arguments do
		if type(key) ~= "string" then
			continue
		end

		local field = fields[key]
		assert(field, `unknown argument: {key}`)

		if not isAbsent(value) then
			checkValue(field, value)
		end
	end
end

return checkArguments
