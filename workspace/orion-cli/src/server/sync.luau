local archivist = require("@archivist")
local json = require("@std/json")
local task = require("@std/task")
local time = require("@std/time")

local findRefreshSooner = require("@root/server/findRefreshSooner")
local getAdapter = require("@root/sources/getAdapter")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local githubTypes = require("@root/sources/github/types")
local loadDoc = require("@root/storage/canvases/loadDoc")
local readFocus = require("@root/storage/focus/readFocus")
local runCommand = require("@root/common/process/command")
local runTransaction = require("@root/storage/transactions/runTransaction")
local types = require("@root/types")

type Runner = types.CommandRunner
type PollState = githubTypes.PollState
type Want = githubTypes.Want

-- An unforced request waits this long after the last sweep.
local THROTTLE_SECONDS = 60
-- Compares every open card's `updatedAt`, which catches the viewer's own and
-- agents' activity.
local SWEEP_SECONDS = 2 * 60
-- Sweeps `updatedAt` for only the cards that refresh sooner, such as the ones
-- in view, between full sweeps.
local SOONER_SECONDS = 30
-- Fetches everything, which catches mergeability: it changes when the base
-- branch moves, and nothing else reports it.
local FULL_SECONDS = 15 * 60
-- Rereads the checks of cards whose checks are pending, since a finished check
-- run moves neither `updatedAt` nor notifications.
local CHECKS_SECONDS = 30
local logger = archivist.getLogger("orion.sync")
local sync = {}

-- How often `orion server start` calls `tickAsync`. Each tick runs at most one
-- pass, and only when one is due.
sync.TICK_SECONDS = 15

--[[
	Keeps the active canvas's pull request cards current. A full pass fetches
	every open card, at startup, on a canvas switch, when forced, and every 15
	minutes. Between them, `tickAsync` polls notifications as often as GitHub
	allows, sweeps `updatedAt` every two minutes, and rereads pending checks
	every 30 seconds, fetching only the cards that changed and writing nothing
	when none did. The cards that refresh sooner, which are the ones the app has
	in view, have their `updatedAt` swept every 30 seconds instead. Background
	passes don't report `running`, so they stay quiet in the app.
]]
function sync.create(
	root: string,
	initialWorkspace: string,
	onStatusChanged: (json.Object) -> (),
	runner: Runner?,
	clock: (() -> number)?
)
	local workspace = initialWorkspace
	local generation = 0
	local isRunning = false
	local lastFull = 0
	local lastSweep = 0
	local lastSooner = 0
	local nextPoll = 0
	local nextChecks = 0
	local poll: PollState = { lastModified = {}, interval = 60 }
	local status = json.object({ state = "idle" })
	local now = clock or os.time
	local command = runner or runCommand
	local loop = {}

	local function setStatus(nextStatus: json.Object)
		status = nextStatus
		onStatusChanged(status)
	end

	-- Runs a full pass without `want`, or a pass limited to what changed with
	-- it. `sweepsSooner` adds a sweep of the cards that refresh sooner, found
	-- from the snapshot the pass reads.
	local function runPassAsync(want: Want?, isQuiet: boolean, sweepsSooner: boolean?): json.Object
		local pass = if want == nil
			then "full"
			elseif want.sweep then "sweep"
			elseif sweepsSooner then "sooner"
			elseif want.notifications then "poll"
			else "checks"
		local started = generation
		local target = workspace
		local startedAt = time.now()
		isRunning = true

		if not isQuiet then
			local running = json.object(status)
			running.state = "running"
			running.message = nil
			setStatus(running)
		end

		local failures: { string } = {}
		local fetched = 0
		local sooner = 0
		local didWrite = false

		-- Fetch from a snapshot, then take the workspace lock only to apply, so
		-- edits don't wait on GitHub.
		local didSucceed, failure = pcall(function()
			local dir = getWorkspaceDir(root, target)
			local verbs = assert(getAdapter("github").source)
			local snapshot = loadDoc(dir)
			local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ") :: string
			local apply: ((types.Doc) -> githubTypes.Report)?

			if want == nil then
				apply = assert(verbs.refreshAsync)(snapshot, command, { now = timestamp })
			else
				if sweepsSooner and not want.sweep then
					local cards = findRefreshSooner(snapshot, readFocus(dir))
					want.sweepCards = cards

					for _ in cards do
						sooner += 1
					end
				end

				local changed = assert(verbs.refreshChangedAsync)(snapshot, command, poll, want, timestamp)
				failures, fetched, apply = changed.failures, changed.fetched, changed.apply
			end

			local applyStep = apply

			if applyStep then
				runTransaction(dir, function(doc)
					local report = applyStep(doc)
					failures = report.failures
					fetched = if want == nil then report.checked else fetched
				end)
				didWrite = true
			end
		end)

		local finishedAt = os.date("!%Y-%m-%dT%H:%M:%SZ") :: string
		local elapsed = math.floor(time.since(startedAt) * 1000)

		if didSucceed and pass == "sooner" then
			logger.debug("sooner refresh of", target, "swept", sooner, "ids, fetched", fetched, "in", elapsed, "ms")
		elseif didSucceed then
			logger.debug(pass, "refresh of", target, "fetched", fetched, "cards in", elapsed, "ms, wrote", didWrite)
		end

		if started == generation then
			if didSucceed and #failures > 0 then
				local first = failures[1]:match("^[^\r\n]*")
				logger.warn(pass, "refresh of", target, "couldn't fetch", #failures, "parts:", first)
				setStatus(json.object({ state = "error", lastRun = finishedAt, message = `Couldn't fetch {first}` }))
			elseif didSucceed then
				setStatus(json.object({ state = "idle", lastRun = finishedAt }))
			else
				local message = tostring(failure):match("([^\r\n]+)$") or tostring(failure)
				logger.err(pass, "refresh of", target, "failed after", elapsed, "ms:", message)
				setStatus(json.object({ state = "error", lastRun = finishedAt, message = message }))
			end

			local finished = now()

			if want == nil then
				lastFull = finished
			end

			if want == nil or want.sweep then
				lastSweep = finished
			end

			if want == nil or want.sweep or sweepsSooner then
				lastSooner = finished
			end

			if want == nil or want.notifications then
				nextPoll = finished + poll.interval
			end

			if want == nil or want.checks then
				nextChecks = finished + CHECKS_SECONDS
			end
		end

		isRunning = false

		if started ~= generation then
			task.defer(function()
				loop.runAsync(true)
			end)
		end

		return status
	end

	function loop.getStatus(): json.Object
		return status
	end

	function loop.switchTo(name: string)
		if name == workspace then
			return
		end

		workspace = name
		generation += 1
		lastFull, lastSweep, lastSooner, nextPoll, nextChecks = 0, 0, 0, 0, 0
		status = json.object({ state = "idle" })
	end

	-- Runs a pass someone asked for: a full one when forced or when the canvas
	-- hasn't had one, otherwise a sweep.
	function loop.runAsync(isForced: boolean?): json.Object
		if isRunning then
			return status
		end

		if isForced or lastFull == 0 then
			return runPassAsync(nil, false)
		end

		if now() - lastSweep < THROTTLE_SECONDS then
			return status
		end

		return runPassAsync({ notifications = true, sweep = true, checks = true }, false)
	end

	-- Runs whichever background pass is due, if any.
	function loop.tickAsync()
		if isRunning then
			return
		end

		local current = now()

		if lastFull == 0 then
			runPassAsync(nil, false)
			return
		elseif current - lastFull >= FULL_SECONDS then
			runPassAsync(nil, true)
			return
		end

		local want: Want = {
			notifications = current >= nextPoll,
			sweep = current - lastSweep >= SWEEP_SECONDS,
			checks = current >= nextChecks,
		}
		local sweepsSooner = not want.sweep and current - lastSooner >= SOONER_SECONDS

		if want.notifications or want.sweep or want.checks or sweepsSooner then
			runPassAsync(want, true, sweepsSooner)
		end
	end

	return loop
end

return table.freeze(sync)
