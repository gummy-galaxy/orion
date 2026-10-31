local system = require("@std/system")

local runCommand = require("@root/common/process/command")
local types = require("@root/types")

type CommandRunner = types.CommandRunner

--[[
	Says whether a process is still running. Windows has no `kill`, and Git for
	Windows' `kill` only knows its own processes, so Windows asks `tasklist`.
	It exits 0 whether or not the process exists, so the answer is whether its
	output lists the pid. `isWindows` defaults to the platform running Orion.
]]
local function isProcessAlive(processId: number, runner: CommandRunner?, isWindows: boolean?): boolean
	local run = runner or runCommand

	if if isWindows == nil then system.win32 else isWindows then
		local result = run({ "tasklist", "/FI", `PID eq {processId}`, "/FO", "CSV", "/NH" })
		return result.ok and string.find(result.stdout, `"{processId}"`, 1, true) ~= nil
	end

	return run({ "kill", "-0", tostring(processId) }).ok
end

return isProcessAlive
