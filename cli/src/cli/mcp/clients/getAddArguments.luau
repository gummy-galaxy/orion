local constants = require("@root/cli/mcp/clients/constants")
local getDataDirOverride = require("@root/cli/mcp/clients/getDataDirOverride")
local mcpTypes = require("@root/cli/mcp/types")

type ClientRequest = mcpTypes.ClientRequest

local function getAddArguments(client: string, request: ClientRequest): { string }
	local arguments = { "mcp", "add", "orion" }

	if client == "claude" then
		table.insert(arguments, "-s")
		table.insert(arguments, "user")
	end

	local dataDir = getDataDirOverride(request.environment)

	if dataDir then
		table.insert(arguments, if client == "claude" then "-e" else "--env")
		table.insert(arguments, `ORION_DATA_DIR={dataDir}`)
	end

	table.insert(arguments, "--")
	table.insert(arguments, tostring(request.binary))

	for _, argument in constants.serveArguments do
		table.insert(arguments, argument)
	end

	return arguments
end

return getAddArguments
