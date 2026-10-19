local system = require("@std/system")
local test = require("@std/test")

local runProgram = require("@root/runProgram")

-- These rely on a POSIX shell, which Windows runners don't have.
if not system.win32 then
	test.case("returns when the program succeeds", function()
		runProgram("exit", { "0" })
	end)

	test.case("names the command and its exit code when it fails", function(assert)
		local succeeded, failure = pcall(function()
			runProgram("exit", { "3" })
		end)
		assert.eq(succeeded, false)
		assert.eq(failure, "exit 3 exited with code 3")
	end)

	test.case("names the signal that killed the program", function(assert)
		local succeeded, failure = pcall(function()
			runProgram("kill", { "-SEGV", "$$" })
		end)
		assert.eq(succeeded, false)
		assert.eq(failure, "kill -SEGV $$ was killed by signal 11 (SIGSEGV)")
	end)
end
