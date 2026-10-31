local task = require("@std/task")

local getBuild = require("@root/telemetry/getBuild")
local getEndpoint = require("@root/telemetry/getEndpoint")
local getQuietReason = require("@root/telemetry/getQuietReason")
local getStatus = require("@root/telemetry/getStatus")
local sendBatchAsync = require("@root/telemetry/sendBatchAsync")
local splitBatches = require("@root/telemetry/splitBatches")
local takeQueue = require("@root/telemetry/takeQueue")
local telemetryTypes = require("@root/telemetry/types")

type Build = telemetryTypes.Build

local telemetrySender = {}

-- How often queued events go out. The backend allows 30 batches a minute per
-- install, far more than this sends.
telemetrySender.SEND_SECONDS = 60
-- Long enough for a slow network, short enough that a backend that can't be
-- reached doesn't keep a send hanging.
telemetrySender.TIMEOUT_SECONDS = 5

export type Options = {
	environment: { [string]: string },
	-- A server started for the app's dev server, which never sends.
	isDevServer: boolean?,
	build: Build?,
	-- Stands in for sending in specs.
	sendBatchAsync: typeof(sendBatchAsync)?,
}

--[[
	Sends the queue from `orion server start` in the background. Each send takes
	the whole queue. When sending isn't allowed, because nobody opted in, an
	override is set, or this is a dev build, perf run, or CI, the queue is
	dropped rather than kept for later. A batch that fails is dropped too, with
	no retry and nothing shown to the person.
]]
function telemetrySender.create(root: string, options: Options)
	local build = options.build or getBuild()
	local send = options.sendBatchAsync or sendBatchAsync
	local isClosed = false
	local isFlushing = false
	local sender = {}

	-- Sends what's queued now and returns how many events were accepted.
	function sender.flushAsync(): number
		if isFlushing then
			return 0
		end

		isFlushing = true

		local didFlush, accepted = pcall(function(): number
			local events = takeQueue(root, os.date("!%Y-%m-%dT%H:%M:%SZ") :: string)
			local status = getStatus(root, options.environment)
			local isQuiet = options.isDevServer or getQuietReason(options.environment, build) ~= nil
			local count = 0

			if #events == 0 or not status.enabled or not status.installId or isQuiet then
				return count
			end

			local endpoint = getEndpoint(options.environment)

			for _, batch in splitBatches(events) do
				if send(endpoint, status.installId :: string, build, batch, telemetrySender.TIMEOUT_SECONDS) then
					count += #batch
				end
			end

			return count
		end)

		isFlushing = false

		return if didFlush then accepted else 0
	end

	function sender.start()
		task.spawn(function()
			while not isClosed do
				sender.flushAsync()
				task.wait(telemetrySender.SEND_SECONDS)
			end
		end)
	end

	-- Stops sending. Whatever is queued stays on disk for the next server.
	function sender.close()
		isClosed = true
	end

	return sender
end

return table.freeze(telemetrySender)
