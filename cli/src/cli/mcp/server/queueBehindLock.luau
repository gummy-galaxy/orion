local fileNames = require("@root/fileNames")
local mcpTypes = require("@root/cli/mcp/types")

type Run = mcpTypes.Run

-- The store gives up on its lock after a few seconds. A crashed writer's lock is reclaimed after 30, so waiting
-- that long covers every holder that will ever let go.
local QUEUE_TIMEOUT_SECONDS = 30
local LOCK_TIMEOUT_PATTERN = "timed out waiting for (.-" .. (fileNames.lock:gsub("%p", "%%%0")) .. ")$"

-- Returns the lock path when a run failed because another process held the canvas lock.
local function findLockPath(message: unknown): string?
	return (string.match(tostring(message), LOCK_TIMEOUT_PATTERN))
end

-- The server answers one call at a time, so calls already wait in line behind each other. This keeps the call at the
-- front waiting while another process, such as the app's server or another agent's MCP server, holds the lock, by
-- running it again whenever the store times out. A timed-out attempt never acquired the lock, so it wrote nothing.
-- Each attempt's output is held back until it succeeds, and the call fails once it has waited past timeoutSeconds.
local function queueBehindLock(run: Run, timeoutSeconds: number?): Run
	local timeout = timeoutSeconds or QUEUE_TIMEOUT_SECONDS

	return function(argv: { string }, write: (string) -> ())
		local started = os.clock()

		while true do
			local lines: { string } = {}
			local ok, message = pcall(run, argv, function(line: string)
				table.insert(lines, line)
			end)

			if ok then
				for _, line in lines do
					write(line)
				end

				return
			end

			local lockPath = findLockPath(message)

			if lockPath == nil then
				error(message, 0)
			end

			local waited = os.clock() - started

			if waited >= timeout then
				error(
					`Gave up after waiting {math.floor(waited)} seconds for another Orion process to release {lockPath}. `
						.. "Nothing was changed; try the call again.",
					0
				)
			end
		end
	end
end

return queueBehindLock
