local process = require("@std/process")

local runCommand = require("@root/command")
local types = require("@root/types")

type CommandRunner = types.CommandRunner

-- Lute has no parent pid API, so ask ps.
local function getParentPid(runner: CommandRunner?, pid: number?): number?
	local run = runner or runCommand
	local result = run({ "ps", "-o", "ppid=", "-p", tostring(pid or process.pid()) })
	if not result.ok then
		return nil
	end
	return tonumber((result.stdout:gsub("%s", "")))
end

return getParentPid
