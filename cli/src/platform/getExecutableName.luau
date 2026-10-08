local platformTypes = require("@root/platform/types")

type Platform = platformTypes.Platform

local function getExecutableName(platform: Platform, name: string): string
	return if platform == "windows" then `{name}.exe` else name
end

return getExecutableName
