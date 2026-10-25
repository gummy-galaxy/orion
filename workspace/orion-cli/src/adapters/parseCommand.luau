local json = require("@std/json")

local function parseCommand(value: string): { string }
	local succeeded, decoded = pcall(json.deserialize, value)
	local array = if succeeded then json.asArray(decoded :: json.Value) else nil
	assert(array and #array > 0, "--command must be a nonempty JSON array")
	local result = {}

	for _, part in array do
		assert(type(part) == "string" and part ~= "", "--command must contain only nonempty strings")
		local lower = part:lower()

		for _, secret in { "--token", "--password", "--secret", "--api-key", "--auth" } do
			assert(not lower:find(secret, 1, true), "do not put credentials in --command")
		end

		assert(not lower:match("https?://[^/]*@"), "do not put credentials in --command")
		table.insert(result, part)
	end

	return result
end

return parseCommand
