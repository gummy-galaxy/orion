local assertOrionBinary = require("@root/cli/mcp/clients/assertOrionBinary")
local findCommand = require("@root/cli/mcp/clients/findCommand")
local getAddArguments = require("@root/cli/mcp/clients/getAddArguments")
local getClientCommand = require("@root/cli/mcp/clients/getClientCommand")
local getCursorConfigPath = require("@root/cli/mcp/clients/getCursorConfigPath")
local getRemoveArguments = require("@root/cli/mcp/clients/getRemoveArguments")
local isCursorAvailable = require("@root/cli/mcp/clients/isCursorAvailable")
local mcpTypes = require("@root/cli/mcp/types")
local runClientCommand = require("@root/cli/mcp/clients/runClientCommand")
local writeCursorConfig = require("@root/cli/mcp/clients/writeCursorConfig")

type ClientRequest = mcpTypes.ClientRequest

-- Skips clients that aren't installed unless one was named, and fails when none registered.
local function registerClients(request: ClientRequest)
	assertOrionBinary(request)

	local registered = 0

	for _, client in request.clients do
		if client == "cursor" then
			if isCursorAvailable(request) or #request.clients == 1 then
				writeCursorConfig(request)
				request.write(
					`Registered orion in {getCursorConfigPath(request.home)}. Restart Cursor or toggle the server in Settings.`
				)
				registered += 1
			else
				request.write("Skipped Cursor: ~/.cursor was not found.")
			end
		else
			local program = findCommand(client, request.environment, request.platform)

			if program == nil then
				assert(#request.clients ~= 1, `{client} is not on PATH`)
				request.write(`Skipped {client}: {client} is not on PATH.`)
			else
				-- Remove first so registering again replaces an older entry.
				runClientCommand(
					request.runner,
					getClientCommand(program, client, getRemoveArguments(client), request.environment, request.platform),
					false
				)
				runClientCommand(
					request.runner,
					getClientCommand(
						program,
						client,
						getAddArguments(client, request),
						request.environment,
						request.platform
					),
					true
				)
				request.write(`Registered orion with {client}.`)
				registered += 1
			end
		end
	end

	if #request.clients > 0 then
		assert(registered > 0, "No MCP clients were registered.")
	end

	request.write(`Clients will run {request.binary} mcp serve.`)
end

return registerClients
