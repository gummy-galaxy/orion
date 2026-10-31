local archivist = require("@archivist")
local task = require("@std/task")

local drainTelemetryQueue = require("@root/telemetry/drainTelemetryQueue")
local getBuild = require("@root/getBuild")
local getTelemetryConfigAsync = require("@root/telemetry/getTelemetryConfigAsync")
local getTelemetryEndpoint = require("@root/telemetry/getTelemetryEndpoint")
local getTelemetryQuietReason = require("@root/telemetry/getTelemetryQuietReason")
local getTelemetryStatus = require("@root/telemetry/getTelemetryStatus")
local sendTelemetryBatchAsync = require("@root/telemetry/sendTelemetryBatchAsync")
local splitTelemetryBatches = require("@root/telemetry/splitTelemetryBatches")
local telemetryTypes = require("@root/telemetry/types")
local types = require("@root/types")

type Build = types.Build
type Limits = telemetryTypes.Limits

local logger = archivist.getLogger("orion.telemetry")

-- What the backend took when this build shipped, used until it says otherwise.
local DEFAULT_LIMITS: Limits = { maxEvents = 100, maxBytes = 64 * 1024 }

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
	-- Stand in for the backend in specs.
	sendTelemetryBatchAsync: typeof(sendTelemetryBatchAsync)?,
	getTelemetryConfigAsync: typeof(getTelemetryConfigAsync)?,
}

--[[
	Sends the queue from `orion server start` in the background. Each send takes
	the whole queue. When sending isn't allowed, because nobody opted in, an
	override is set, or this is a dev build, perf run, or CI, the queue is
	dropped rather than kept for later. A batch that fails is dropped too, with
	no retry and nothing shown to the person beyond a warning in the log.

	Batches are sized by the limits the backend publishes, asked for before the
	first send of each run. Until it answers, the limits this build shipped with
	stand in, and the next send asks again.
]]
function telemetrySender.create(root: string, options: Options)
	local build = options.build or getBuild()
	local send = options.sendTelemetryBatchAsync or sendTelemetryBatchAsync
	local fetchLimits = options.getTelemetryConfigAsync or getTelemetryConfigAsync
	local limits: Limits?
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
			local events = drainTelemetryQueue(root, os.date("!%Y-%m-%dT%H:%M:%SZ") :: string)
			local status = getTelemetryStatus(root, options.environment)
			local isQuiet = options.isDevServer or getTelemetryQuietReason(options.environment, build) ~= nil
			local count = 0

			if #events == 0 or not status.enabled or not status.installId or isQuiet then
				return count
			end

			local endpoint = getTelemetryEndpoint(options.environment)

			if not limits then
				local fetched, failure = fetchLimits(endpoint, telemetrySender.TIMEOUT_SECONDS)

				if not fetched then
					logger.warn("using built-in batch limits:", failure)
				end

				limits = fetched
			end

			for _, batch in splitTelemetryBatches(events, limits or DEFAULT_LIMITS) do
				local isAccepted, failure =
					send(endpoint, status.installId :: string, build, batch, telemetrySender.TIMEOUT_SECONDS)

				if isAccepted then
					count += #batch
				else
					logger.warn("dropped", #batch, "usage events:", failure or "the backend refused them")
				end
			end

			return count
		end)

		isFlushing = false

		if not didFlush then
			logger.warn("could not send usage events:", accepted)
		end

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
