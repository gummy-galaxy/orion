local process = require("@std/process")

-- Whether a terminal is attached to standard input, which tells a person typing
-- a command from an agent running it. Lute can't ask directly, so a shell
-- inherits stdin and reports it with `test -t 0`. Returns nil where there's no
-- `sh` to ask, such as Windows.
local function isInteractiveTerminal(): boolean?
	local options: process.ProcessRunOptions = { stdio = "inherit" }
	local didRun, result = pcall(process.run, { "sh", "-c", "test -t 0" }, options)

	if not didRun then
		return nil
	end

	return result.exitcode == 0
end

return isInteractiveTerminal
