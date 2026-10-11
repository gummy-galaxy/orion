local process = require("@std/process")

-- Runs `gh` with the given arguments and returns its stdout, or fails with its stderr.
local function runGh(argv: { string }): string
	local result = process.run({ "gh", table.unpack(argv) })
	assert(result.ok, `gh {argv[1]} failed: {result.stderr}`)

	return result.stdout
end

return runGh
