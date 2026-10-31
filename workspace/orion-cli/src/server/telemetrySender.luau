local archivist = require("@archivist")
local task = require("@std/task")

local drainTelemetryQueue = require("@root/telemetry/drainTelemetryQueue")
local formatTimestamp = require("@root/time/formatTimestamp")
local getBuild = require("@root/getBuild")
local getTelemetryConfigAsync = require("@root/telemetry/getTelemetryConfigAsync")
local getTelemetryEndpoint = require("@root/telemetry/getTelemetryEndpoint")
local getTelemetryQuietReason = require("@root/telemetry/getTelemetryQuietReason")
local getTelemetryStatus = require("@root/telemetry/getTelemetryStatus")
local sendTelemetryBatchAsync = require("@root/telemetry/sendTelemetryBatchAsync")
local splitTelemetryBatches = require("@root/telemetry/splitTelemetryBatches")
local telemetryConstants = require("@root/telemetry/constants")
local telemetryTypes = require("@root/telemetry/types")
local types = require("@root/types")

type Build = types.Build
type TelemetryConfig = telemetryTypes.TelemetryConfig

local logger = archivist.getLogger("orion.telemetry")

local telemetrySender = {}

export type Options = {
	environment: { [string]: string },
	-- True when the app's dev server started this server for local work on the
	-- app, which `--dev-port` marks. Such a server never sends.
	isDevServer: boolean?,
	build: Build?,
	-- Specs pass these to stand in for the backend.
	sendTelemetryBatchAsync: typeof(sendTelemetryBatchAsync)?,
	getTelemetryConfigAsync: typeof(getTelemetryConfigAsync)?,
}

--[[
	Events wait in a queue file in the data folder until `orion server start`
	sends them. This creates the sender, which runs in the background and sends
	the queue once a minute.

	Each send empties the whole queue and splits it into batches. Sending can be
	off for several reasons: nobody opted in, `DO_NOT_TRACK` or
	`ORION_TELEMETRY=0` is set, or this is a dev build, a perf run
	(`ORION_PERF=1`), CI, or a server started for the app's dev server. When
	it's off, the queue is deleted rather than kept for later. A batch the
	backend doesn't accept is dropped too. It isn't retried, and the only sign
	of it is a warning in the log.

	The backend publishes how big a batch may be. The server asks for those
	limits before its first send and keeps them for the rest of the run. If the
	backend can't be reached, the server uses the limits this build shipped with
	and asks again on the next send.
]]
function telemetrySender.create(root: string, options: Options)
	local build = options.build or getBuild()
	local send = options.sendTelemetryBatchAsync or sendTelemetryBatchAsync
	local getConfigAsync = options.getTelemetryConfigAsync or getTelemetryConfigAsync
	local config: TelemetryConfig?
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
			local events = drainTelemetryQueue(root, formatTimestamp())
			local status = getTelemetryStatus(root, options.environment)
			local isQuiet = options.isDevServer or getTelemetryQuietReason(options.environment, build) ~= nil
			local count = 0

			if #events == 0 or not status.enabled or not status.installId or isQuiet then
				return count
			end

			if not config then
				local configEndpoint = getTelemetryEndpoint(options.environment, "config")
				local fetched, failure = getConfigAsync(configEndpoint, telemetryConstants.TIMEOUT_SECONDS)

				if not fetched then
					logger.warn("using built-in batch limits:", failure)
				end

				config = fetched
			end

			local limits = if config then config.limits else telemetryConstants.DEFAULT_LIMITS
			local eventsEndpoint = getTelemetryEndpoint(options.environment, "events")

			for _, batch in splitTelemetryBatches(events, limits) do
				-- Sending yields, so the person can opt out between batches.
				-- Read their choice again first, and stop if they turned
				-- sharing off or it's now a different install.
				local current = getTelemetryStatus(root, options.environment)

				if not current.enabled or current.installId ~= status.installId then
					break
				end

				local isAccepted, failure =
					send(eventsEndpoint, status.installId :: string, build, batch, telemetryConstants.TIMEOUT_SECONDS)

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
				task.wait(telemetryConstants.SEND_SECONDS)
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
