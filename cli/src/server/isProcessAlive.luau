local runCommand = require("@root/command")
local types = require("@root/types")

type CommandRunner = types.CommandRunner

local function isProcessAlive(pid: number, runner: CommandRunner?): boolean
	local run = runner or runCommand
	return run({ "kill", "-0", tostring(pid) }).ok
end

return isProcessAlive
