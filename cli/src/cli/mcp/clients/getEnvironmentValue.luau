-- Windows environment names are case-insensitive, so fall back to a case-insensitive match.
local function getEnvironmentValue(environment: { [string]: string }, name: string): string?
	if environment[name] then
		return environment[name]
	end

	local wanted = string.upper(name)

	for key, value in environment do
		if string.upper(key) == wanted then
			return value
		end
	end

	return nil
end

return getEnvironmentValue
