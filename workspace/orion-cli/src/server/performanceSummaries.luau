local task = require("@std/task")

local queueEvents = require("@root/telemetry/queueEvents")
local summarizeDurations = require("@root/telemetry/summarizeDurations")
local telemetryTypes = require("@root/telemetry/types")

type Build = telemetryTypes.Build
type QueuedEvent = telemetryTypes.QueuedEvent

export type Metric = "derive" | "server_flush"

local METRICS: { Metric } = { "derive", "server_flush" }

local performanceSummaries = {}

-- How often the timings gathered so far are queued. The desktop app may stop
-- the server without warning, so waiting for the end of a session would lose
-- most of them.
performanceSummaries.SUMMARY_SECONDS = 300
-- Enough samples for a steady p95 over a stretch. Later ones still count
-- toward sample_count.
performanceSummaries.MAX_SAMPLES = 1000

export type Options = {
	environment: { [string]: string },
	build: Build?,
}

export type Timings = {
	record: (metric: Metric, durationMs: number) -> (),
	setCanvasSize: (cardCount: number, groupCount: number) -> (),
}

--[[
	Times `derive` passes and applied edits in `orion server start`, and queues
	a `performance_summarized` event for each every few minutes and when the
	server stops cleanly. Each event covers the stretch since the last one, and
	carries the size of the canvas last derived, so timings can be compared on
	canvases of the same size.
]]
function performanceSummaries.create(root: string, options: Options)
	local samples: { [Metric]: { number } } = { derive = {}, server_flush = {} }
	local counts: { [Metric]: number } = { derive = 0, server_flush = 0 }
	local cardCount = 0
	local groupCount = 0
	local isClosed = false
	local summaries = {}

	function summaries.record(metric: Metric, durationMs: number)
		counts[metric] += 1

		if #samples[metric] < performanceSummaries.MAX_SAMPLES then
			table.insert(samples[metric], durationMs)
		end
	end

	function summaries.setCanvasSize(cards: number, groups: number)
		cardCount = cards
		groupCount = groups
	end

	-- Queues a summary for each metric timed since the last one, and starts
	-- the next stretch. Returns how many were queued.
	function summaries.queue(): number
		local events: { QueuedEvent } = {}
		local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ") :: string

		for _, metric in METRICS do
			local summary = summarizeDurations(samples[metric])

			if summary then
				table.insert(events, {
					name = "performance_summarized",
					timestamp = timestamp,
					properties = {
						metric = metric,
						sample_count = counts[metric],
						p50_ms = summary.p50,
						p95_ms = summary.p95,
						max_ms = summary.max,
						card_count = cardCount,
						group_count = groupCount,
					},
				})
			end

			samples[metric] = {}
			counts[metric] = 0
		end

		return queueEvents(root, events, options.environment, options.build)
	end

	function summaries.start()
		task.spawn(function()
			while true do
				task.wait(performanceSummaries.SUMMARY_SECONDS)

				if isClosed then
					return
				end

				pcall(summaries.queue)
			end
		end)
	end

	-- Queues the last stretch. Appending to the queue doesn't touch the
	-- network, so it's safe while the server shuts down.
	function summaries.close()
		if isClosed then
			return
		end

		isClosed = true
		pcall(summaries.queue)
	end

	return summaries
end

return table.freeze(performanceSummaries)
