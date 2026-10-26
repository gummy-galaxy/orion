local path = require("@std/path")
local process = require("@std/process")

type Options = {
	cwd: path.Pathlike?,
	captureOutput: boolean?,
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
	Runs a program through the shell, and raises an error that names the command
	and how it ended when it fails. The shell finds programs such as `npm.cmd`
	on Windows. Output passes through to the terminal, unless `captureOutput` is
	set: then it returns stdout with its surrounding newlines trimmed, and a
	failure's error also carries stderr.
]]
local function run(program: string, arguments: { string }, options: Options?): string?
	local captureOutput = options ~= nil and options.captureOutput == true
	local command = table.concat({ program, table.unpack(arguments) }, " ")
	print(`> {command}`)

	local result = process.system(command, {
		stdio = if captureOutput then "default" else "inherit",
		cwd = if options and options.cwd then tostring(options.cwd) else nil,
	})

	if result.ok then
		return if captureOutput then (result.stdout:gsub("^\n+", ""):gsub("\n+$", "")) else nil
	end

	local stderr = if captureOutput and result.stderr ~= "" then `:\n{result.stderr}` else ""

	if result.signal then
		local name = SIGNAL_NAMES[result.signal]
		error(`{command} was killed by signal {result.signal}{if name then ` ({name})` else ""}{stderr}`, 0)
	end

	error(`{command} exited with code {result.exitcode}{stderr}`, 0)
end

return run
