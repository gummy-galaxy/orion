local process = require("@std/process")

--[[
	Runs a script's body and exits 1 when it raises. Lute prints an error raised
	after the scheduler resumes the main thread, such as after `task.wait` or a
	`process.run` whose program is missing, but still exits 0, so CI would pass
	the step.
]]
local function runScript(body: () -> ...unknown)
	local succeeded, failure = xpcall(body, function(message: unknown): string
		return debug.traceback(tostring(message), 2)
	end)

	if not succeeded then
		print(failure)
		process.exit(1)
	end
end

return runScript
