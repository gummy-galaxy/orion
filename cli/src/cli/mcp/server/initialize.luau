local json = require("@std/json")

local protocol = require("@root/cli/mcp/server/protocol")

-- Agrees to the client's protocol version when the server speaks it, and offers the newest otherwise.
local function initialize(params: json.Object): json.Object
	local requested = params.protocolVersion
	local version = protocol.versions[1]

	if type(requested) == "string" and table.find(protocol.versions, requested) then
		version = requested
	end

	return json.object({
		protocolVersion = version,
		capabilities = json.object({ tools = json.object({ listChanged = false }) }),
		serverInfo = json.object({ name = "orion", version = protocol.serverVersion }),
	})
end

return initialize
