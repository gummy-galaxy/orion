local fs = require("@std/fs")
local json = require("@std/json")

local function readCursorConfig(file: string): json.Object
	if not fs.exists(file) then
		return json.object({ mcpServers = json.object({}) })
	end

	local parsed = json.asObject(json.deserialize(fs.readFileToString(file)) :: json.Value)
	assert(parsed, `invalid Cursor MCP config at {file}`)

	if not json.asObject(parsed.mcpServers) then
		parsed.mcpServers = json.object({})
	end

	return parsed
end

return readCursorConfig
