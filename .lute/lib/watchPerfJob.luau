local fetchWatchDecision = require("@lib/fetchWatchDecision")
local getHeadSha = require("@lib/getHeadSha")
local task = require("@std/task")
local time = require("@std/time")
local types = require("@lib/types")

type WatchDecision = types.WatchDecision

local WATCH_SECONDS = 60 * 60
local POLL_SECONDS = 30

-- Watches a pull request's head commit until its perf job is running or finished, was skipped, or never queued, or until
-- an hour has passed. A poll that fails is retried on the next one, so a flaky GitHub response doesn't end the watch.
local function watchPerfJob(repository: string, pullRequest: string)
	local headSha = getHeadSha(repository, pullRequest)
	local started = time.now()

	while true do
		local decision: WatchDecision = { stop = false, reason = "waiting" }
		local polled, result = pcall(fetchWatchDecision, repository, headSha)

		if polled then
			decision = result
		else
			print(`::warning::Poll failed, trying again: {result}`)
		end

		print(`Watching PR #{pullRequest} at {headSha}: {decision.reason}`)

		if decision.stop then
			return
		end

		if time.since(started) >= WATCH_SECONDS then
			print(`::warning::Stopped watching PR #{pullRequest} after an hour, and its perf job has not started`)
			return
		end

		task.wait(POLL_SECONDS)
	end
end

return watchPerfJob
