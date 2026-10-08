local getEnvironmentValue = require("@root/cli/mcp/clients/getEnvironmentValue")
local platformDirs = require("@root/platformDirs")

type Platform = platformDirs.Platform

local function getCommandExtensions(platform: Platform, environment: { [string]: string }): { string }
	if platform ~= "windows" then
		return { "" }
	end

	local extensions: { string } = {}

	for extension in string.gmatch(getEnvironmentValue(environment, "PATHEXT") or ".COM;.EXE;.BAT;.CMD", "[^;]+") do
		table.insert(extensions, string.lower(extension))
	end

	return extensions
end

return getCommandExtensions
