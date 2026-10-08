local function getRemoveArguments(client: string): { string }
	local arguments = { "mcp", "remove", "orion" }

	if client == "claude" then
		table.insert(arguments, "-s")
		table.insert(arguments, "user")
	end

	return arguments
end

return getRemoveArguments
