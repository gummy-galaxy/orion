local system = require("@std/system")
local test = require("@std/test")

local run = require("@root/common/process/run")

-- These rely on a POSIX shell, which Windows runners don't have.
if not system.win32 then
	test.case("returns when the program succeeds", function()
		run("exit", { "0" })
	end)

	test.case("names the command and its exit code when it fails", function(assert)
		local succeeded, failure = pcall(function()
			run("exit", { "3" })
		end)
		assert.eq(succeeded, false)
		assert.eq(failure, "exit 3 exited with code 3")
	end)

	test.case("names the signal that killed the program", function(assert)
		local succeeded, failure = pcall(function()
			run("kill", { "-SEGV", "$$" })
		end)
		assert.eq(succeeded, false)
		assert.eq(failure, "kill -SEGV $$ was killed by signal 11 (SIGSEGV)")
	end)

	test.case("returns stdout without its surrounding newlines when capturing output", function(assert)
		assert.eq(run("printf", { "'\\nhello\\n\\n'" }, { captureOutput = true }), "hello")
	end)

	test.case("includes stderr in the error when capturing output", function(assert)
		local succeeded, failure = pcall(function()
			run("echo", { "oops", ">&2;", "exit", "4" }, { captureOutput = true })
		end)
		assert.eq(succeeded, false)
		assert.eq(failure, "echo oops >&2; exit 4 exited with code 4:\noops\n")
	end)
end
