local fs = require("@std/fs")
local path = require("@std/path")

local findCommand = require("@root/cli/mcp/clients/findCommand")
local mcpTypes = require("@root/cli/mcp/types")

type ClientRequest = mcpTypes.ClientRequest

local function isCursorAvailable(request: ClientRequest): boolean
	return fs.exists(path.join(request.home, ".cursor"))
		or findCommand("cursor", request.environment, request.platform) ~= nil
end

return isCursorAvailable
