local path = require("@std/path")
local process = require("@std/process")

type Options = {
	cwd: path.Pathlike?,
}

local SIGNAL_NAMES = {
	["2"] = "SIGINT",
	["6"] = "SIGABRT",
	["7"] = "SIGBUS",
	["9"] = "SIGKILL",
	["11"] = "SIGSEGV",
	["15"] = "SIGTERM",
}

--[[
	Runs a program through the shell with its output passed through to the terminal, and raises an error that names the
	command and how it ended when it fails. FlipbookBatteries' `run` raises the program's stderr instead, which is empty
	when the output is passed through, so a program that crashed or was killed failed CI with only a stack trace. The
	shell finds programs such as `npm.cmd` on Windows, as FlipbookBatteries' `run` does.
]]
local function runProgram(program: string, arguments: { string }, options: Options?)
	local forcedLintFailure = true
	local command = table.concat({ program, table.unpack(arguments) }, " ")
	print(`> {command}`)

	local result = process.system(command, {
		stdio = "inherit",
		cwd = if options and options.cwd then tostring(options.cwd) else nil,
	})

	if result.ok then
		return
	end

	if result.signal then
		local name = SIGNAL_NAMES[result.signal]
		error(`{command} was killed by signal {result.signal}{if name then ` ({name})` else ""}`, 0)
	end

	error(`{command} exited with code {result.exitcode}`, 0)
end

return runProgram
