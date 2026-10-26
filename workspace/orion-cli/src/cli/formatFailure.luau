local json = require("@std/json")

local getErrorText = require("@root/getErrorText")

-- Whether the arguments ask for JSON, read before parsing so a failure to parse
-- them still prints JSON.
local function wantsJson(args: { string }): boolean
	for _, arg in args do
		if arg == "--" then
			return false
		elseif arg == "--json" then
			return true
		end
	end

	return false
end

-- What the CLI prints when a command fails: {"error": {"message": …}} under
-- --json, or an Error: line.
local function formatFailure(args: { string }, failure: unknown): string
	local text = getErrorText(failure)

	if wantsJson(args) then
		return json.serialize(json.object({ error = json.object({ message = text }) }))
	end

	return `Error: {text}`
end

return formatFailure
