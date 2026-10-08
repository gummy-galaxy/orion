local getEnvironmentValue = require("@root/cli/mcp/clients/getEnvironmentValue")
local isShellScript = require("@root/cli/mcp/clients/isShellScript")
local platformDirs = require("@root/platformDirs")

type Platform = platformDirs.Platform

local function getClientCommand(
	program: string,
	name: string,
	arguments: { string },
	environment: { [string]: string },
	platform: Platform
): { string }
	local argv: { string }

	-- npm installs Codex and Claude as .cmd shims on Windows, which only cmd.exe can run.
	-- The bare name keeps a quoted path from leading the line, which cmd /c would unquote.
	if platform == "windows" and isShellScript(program) then
		argv = { getEnvironmentValue(environment, "ComSpec") or "cmd.exe", "/d", "/c", name }
	else
		argv = { program }
	end

	for _, argument in arguments do
		table.insert(argv, argument)
	end

	return argv
end

return getClientCommand
