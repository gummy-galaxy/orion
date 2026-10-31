local storeTypes = require("@root/storage/types")
local writerState = require("@root/storage/transactions/writerState")

-- Runs `callback` with `writer` recorded as the writer of every revision it
-- makes, then puts back the writer from before, so a command an MCP server
-- runs is recorded as its own.
local function runAsWriter(writer: storeTypes.Writer, callback: () -> ())
	local previous = writerState.current
	writerState.current = writer
	local succeeded, failure = pcall(callback)
	writerState.current = previous

	if not succeeded then
		error(failure, 0)
	end
end

return runAsWriter
