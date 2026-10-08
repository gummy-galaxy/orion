local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local getCursorConfigPath = require("@root/cli/mcp/clients/getCursorConfigPath")
local readCursorConfig = require("@root/cli/mcp/clients/readCursorConfig")

-- Returns whether Cursor's config had an orion server to remove.
local function removeCursorServer(home: path.Path): boolean
	local file = getCursorConfigPath(home)

	if not fs.exists(file) then
		return false
	end

	local config = readCursorConfig(file)
	local servers = assert(json.asObject(config.mcpServers))

	if servers.orion == nil then
		return false
	end

	servers.orion = nil
	config.mcpServers = servers
	fs.writeStringToFile(file, json.serialize(config, true))
	return true
end

return removeCursorServer
