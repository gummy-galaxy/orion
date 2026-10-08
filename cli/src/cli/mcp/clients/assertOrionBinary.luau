local fs = require("@std/fs")
local path = require("@std/path")

local mcpTypes = require("@root/cli/mcp/types")
local platformDirs = require("@root/platformDirs")

type ClientRequest = mcpTypes.ClientRequest

-- Clients run whatever binary registered them, so a script run through lute would register lute.
local function assertOrionBinary(request: ClientRequest)
	local binary = request.binary
	assert(
		path.basename(binary) == platformDirs.executableName(request.platform, "orion")
			and fs.exists(binary)
			and fs.type(binary) == "file",
		"Run register from the built orion binary, such as cli/build/orion"
	)
end

return assertOrionBinary
