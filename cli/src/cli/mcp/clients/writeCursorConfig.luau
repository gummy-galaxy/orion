local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local constants = require("@root/cli/mcp/clients/constants")
local getCursorConfigPath = require("@root/cli/mcp/clients/getCursorConfigPath")
local getDataDirOverride = require("@root/cli/mcp/clients/getDataDirOverride")
local mcpTypes = require("@root/cli/mcp/types")
local readCursorConfig = require("@root/cli/mcp/clients/readCursorConfig")

type ClientRequest = mcpTypes.ClientRequest

-- Cursor has no command to add a server, so edit its config and keep the other servers.
local function writeCursorConfig(request: ClientRequest)
	local directory = tostring(path.join(request.home, ".cursor"))

	if not fs.exists(directory) then
		fs.createDirectory(directory, { makeParents = true })
	end

	local file = getCursorConfigPath(request.home)
	local config = readCursorConfig(file)
	local servers = assert(json.asObject(config.mcpServers))
	local entry = json.object({ command = request.binary, args = table.clone(constants.serveArguments) })
	local dataDir = getDataDirOverride(request.environment)

	if dataDir then
		entry.env = json.object({ ORION_DATA_DIR = dataDir })
	end

	servers.orion = entry
	config.mcpServers = servers
	fs.writeStringToFile(file, json.serialize(config, true))
end

return writeCursorConfig
