local json = require("@std/json")
local task = require("@std/task")

local applyPulls = require("@root/github/applyPulls")
local collectPulls = require("@root/github/collectPulls")
local runCommand = require("@root/command")
local store = require("@root/store")
local types = require("@root/types")

type Runner = types.CommandRunner

local THROTTLE_SECONDS = 60
local sync = {}

function sync.create(
	root: string,
	initialWorkspace: string,
	publish: (json.Object) -> (),
	runner: Runner?,
	clock: (() -> number)?
)
	local workspace = initialWorkspace
	local generation = 0
	local isRunning = false
	local lastFinished = 0
	local status = json.object({ state = "idle" })
	local now = clock or os.time
	local command = runner or runCommand
	local loop = {}

	local function setStatus(nextStatus: json.Object)
		status = nextStatus
		publish(status)
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
		lastFinished = 0
		status = json.object({ state = "idle" })
	end

	function loop.run(isForced: boolean?): json.Object
		if isRunning or (not isForced and lastFinished > 0 and now() - lastFinished < THROTTLE_SECONDS) then
			return status
		end

		local started = generation
		local target = workspace
		isRunning = true
		local running = json.object(status)
		running.state = "running"
		running.message = nil
		setStatus(running)
		local didSucceed, failure = pcall(function()
			local dir = store.getWorkspaceDir(root, target)
			local fetched = collectPulls(store.load(dir), command, false)
			store.transaction(dir, function(doc)
				applyPulls(doc, fetched, os.date("!%Y-%m-%dT%H:%M:%SZ") :: string)
			end)
		end)

		local finishedAt = os.date("!%Y-%m-%dT%H:%M:%SZ") :: string

		if started == generation then
			if didSucceed then
				setStatus(json.object({ state = "idle", lastRun = finishedAt }))
			else
				local message = tostring(failure):match("([^\r\n]+)$") or tostring(failure)
				setStatus(json.object({ state = "error", lastRun = finishedAt, message = message }))
			end

			lastFinished = now()
		end

		isRunning = false

		if started ~= generation then
			task.defer(function()
				loop.run(true)
			end)
		end

		return status
	end

	return loop
end

return table.freeze(sync)
