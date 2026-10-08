local findCommand = require("@root/cli/mcp/clients/findCommand")
local getClientCommand = require("@root/cli/mcp/clients/getClientCommand")
local getCursorConfigPath = require("@root/cli/mcp/clients/getCursorConfigPath")
local getRemoveArguments = require("@root/cli/mcp/clients/getRemoveArguments")
local mcpTypes = require("@root/cli/mcp/types")
local removeCursorServer = require("@root/cli/mcp/clients/removeCursorServer")
local runClientCommand = require("@root/cli/mcp/clients/runClientCommand")

type ClientRequest = mcpTypes.ClientRequest

local function unregisterClients(request: ClientRequest)
	for _, client in request.clients do
		if client == "cursor" then
			if removeCursorServer(request.home) then
				request.write(`Removed orion from {getCursorConfigPath(request.home)}.`)
			else
				request.write("Cursor had no orion server.")
			end
		else
			local program = findCommand(client, request.environment, request.platform)

			if program == nil then
				assert(#request.clients ~= 1, `{client} is not on PATH`)
				request.write(`Skipped {client}: {client} is not on PATH.`)
			else
				runClientCommand(
					request.runner,
					getClientCommand(program, client, getRemoveArguments(client), request.environment, request.platform),
					false
				)
				request.write(`Removed orion from {client}.`)
			end
		end
	end
end

return unregisterClients
