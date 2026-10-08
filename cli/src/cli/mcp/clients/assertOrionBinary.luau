local fs = require("@std/fs")
local path = require("@std/path")

local getExecutableName = require("@root/platform/getExecutableName")
local mcpTypes = require("@root/cli/mcp/types")

type ClientRequest = mcpTypes.ClientRequest

-- Clients run whatever binary registered them, so a script run through lute would register lute.
local function assertOrionBinary(request: ClientRequest)
	local binary = request.binary
	assert(
		path.basename(binary) == getExecutableName(request.platform, "orion")
			and fs.exists(binary)
			and fs.type(binary) == "file",
		"Run register from the built orion binary, such as cli/build/orion"
	)
end

return assertOrionBinary
