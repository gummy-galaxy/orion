local getErrorText = require("@root/getErrorText")
local serializeFailure = require("@root/cli/serializeFailure")

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

-- Prints a failed command's error. Under --json it's {"error": {"code": …,
-- "message": …}} on stdout, where a script already reads. Otherwise it's an
-- Error: line on stderr, so stdout only ever holds output.
local function reportFailure(args: { string }, failure: unknown, write: (string) -> (), warn: (string) -> ())
	if wantsJson(args) then
		write(serializeFailure(failure))
	else
		warn(`Error: {getErrorText(failure)}`)
	end
end

return reportFailure
