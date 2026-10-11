local command = require("@root/command")

-- Runs `gh` with the given arguments and returns its stdout, or fails with its stderr.
local function runGh(argv: { string }): string
	local result = command({ "gh", table.unpack(argv) }, nil)
	assert(result.ok, `gh {table.concat(argv, " ", 1, 2)} failed: {result.stderr}`)

	return result.stdout
end

return runGh
