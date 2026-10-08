local constants = require("@root/cli/mcp/clients/constants")

local function getClients(name: string?): { string }
	if name == nil or name == "all" then
		return table.clone(constants.names)
	end

	assert(table.find(constants.names, name) ~= nil, "client must be codex, claude, cursor, or all")
	return { name }
end

return getClients
