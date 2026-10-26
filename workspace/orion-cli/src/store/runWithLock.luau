local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local task = require("@std/task")

local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local isProcessAlive = require("@root/server/isProcessAlive")

local LOCK_TIMEOUT_SECONDS = 5
local STALE_LOCK_SECONDS = 30
local ABANDONED_LOCK_SECONDS = 10 * 60

local function release(lockPath: string)
	pcall(function()
		fs.removeDirectory(lockPath, { recursive = true })
	end)
end

-- A lock is abandoned once its owner stamp is stale and its writer is gone. A
-- writer that crashes right after creating the lock leaves no readable stamp,
-- so the lock directory's own age stands in for it. A stamp far past stale is
-- abandoned even if its process id is alive, since the id may have been reused.
local function isLockAbandoned(lockPath: string, ownerPath: path.Path): boolean
	local succeeded, owner = pcall(fs.readFileToString, ownerPath)
	local processId, stamp = nil, nil

	if succeeded then
		local processText, stampText = owner:match("^(%d+)%s(%d+)")
		processId, stamp = tonumber(processText), tonumber(stampText)
	end

	if not stamp then
		local found, metadata = pcall(fs.metadata, lockPath)
		stamp = if found then metadata.modified:toSeconds() else nil
	end

	if not stamp then
		return false
	end

	local age = os.time() - stamp

	if age <= STALE_LOCK_SECONDS then
		return false
	end

	return age > ABANDONED_LOCK_SECONDS or not processId or not isProcessAlive(processId)
end

local function acquire(dir: string): string
	local lockPath = tostring(path.join(dir, fileNames.lock))
	local ownerPath = path.join(lockPath, "owner")
	local deadline = os.time() + LOCK_TIMEOUT_SECONDS

	while true do
		if process.run({ "mkdir", lockPath }).ok then
			fs.writeStringToFile(ownerPath, `{process.pid()} {os.time()}`)
			return lockPath
		end

		-- Reclaim a lock left behind by a writer that crashed.
		if isLockAbandoned(lockPath, ownerPath) then
			release(lockPath)
			continue
		end

		assert(os.time() < deadline, `timed out waiting for {lockPath}`)
		task.wait(0.05)
	end
end

-- Runs `run` while holding the workspace lock, and releases it whether or not
-- `run` fails. Every write to a workspace goes through here: the data file, and
-- the files beside it such as the log.
local function runWithLock<T>(dir: string, run: () -> T): T
	ensureDirectory(dir)

	local lockPath = acquire(dir)
	local succeeded, result = pcall(run)
	release(lockPath)

	if not succeeded then
		error(result, 0)
	end

	return result
end

return runWithLock
