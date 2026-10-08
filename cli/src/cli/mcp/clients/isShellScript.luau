local path = require("@std/path")

local function isShellScript(program: string): boolean
	local extension = string.lower(path.extname(program))
	return extension == ".cmd" or extension == ".bat"
end

return isShellScript
