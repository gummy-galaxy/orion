local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local task = require("@std/task")
local time = require("@std/time")

local ensureDirectory = require("@root/platform/ensureDirectory")
local fileNames = require("@root/fileNames")
local isProcessAlive = require("@root/server/isProcessAlive")

-- A writer gives up once the lock and the front of the queue have both stood
-- still this long. A line of writers that keeps moving never times out.
local LOCK_TIMEOUT_SECONDS = 5
local STALE_LOCK_SECONDS = 30
local ABANDONED_LOCK_SECONDS = 10 * 60
-- How long the ticket at the front can wait on a free lock before its writer
-- is checked for being gone, and how often after that.
local STALLED_TICKET_SECONDS = 1
local POLL_SECONDS = 0.05

local function removeDirectory(directory: string)
	pcall(function()
		fs.removeDirectory(directory, { recursive = true })
	end)
end

-- Makes a directory and says whether this call made it. `mkdir` fails when
-- the directory already exists, so two writers can never both succeed.
local function claim(directory: string): boolean
	return process.run({ "mkdir", directory }).ok
end

local function stamp(directory: string)
	fs.writeStringToFile(path.join(directory, "owner"), `{process.pid()} {os.time()}`)
end

-- A lock is abandoned once its owner stamp is stale and its writer is gone. A
-- writer that crashes right after creating the lock leaves no readable stamp,
-- so the lock directory's own age stands in for it. A stamp far past stale is
-- abandoned even if its process id is alive, since the id may have been reused.
local function isLockAbandoned(lockPath: string): boolean
	local succeeded, owner = pcall(fs.readFileToString, path.join(lockPath, "owner"))
	local processId, stamped = nil, nil

	if succeeded then
		local processText, stampText = owner:match("^(%d+)%s(%d+)")
		processId, stamped = tonumber(processText), tonumber(stampText)
	end

	if not stamped then
		local found, metadata = pcall(fs.metadata, lockPath)
		stamped = if found then metadata.modified:toSeconds() else nil
	end

	if not stamped then
		return false
	end

	local age = os.time() - stamped

	if age <= STALE_LOCK_SECONDS then
		return false
	end

	return age > ABANDONED_LOCK_SECONDS or not processId or not isProcessAlive(processId)
end

-- A ticket is abandoned when its writer is gone. A ticket with no stamp yet
-- belongs to a writer between taking it and stamping it, unless it has been
-- that way for longer than any writer takes.
local function isTicketAbandoned(ticketPath: string): boolean
	local succeeded, owner = pcall(fs.readFileToString, path.join(ticketPath, "owner"))
	local processId = if succeeded then tonumber(owner:match("^(%d+)")) else nil

	if processId then
		return not isProcessAlive(processId)
	end

	local found, metadata = pcall(fs.metadata, ticketPath)
	return found and os.time() - metadata.modified:toSeconds() > STALE_LOCK_SECONDS
end

-- The waiting tickets' numbers, lowest first.
local function listTickets(queuePath: string): { number }
	local tickets = {}
	local found, entries = pcall(fs.listDirectory, queuePath)

	if found then
		for _, entry in entries do
			local ticket = tonumber(entry.name)

			if entry.type == "dir" and ticket then
				table.insert(tickets, ticket)
			end
		end
	end

	table.sort(tickets)

	return tickets
end

-- Takes the number after the highest ticket waiting. Two writers that pick
-- the same number race to make its directory, and the one that loses picks
-- again.
local function takeTicket(queuePath: string): (string, number)
	while true do
		local tickets = listTickets(queuePath)
		local ticket = (tickets[#tickets] or 0) + 1
		local ticketPath = tostring(path.join(queuePath, tostring(ticket)))

		if claim(ticketPath) then
			stamp(ticketPath)
			return ticketPath, ticket
		end
	end
end

local function readOwner(lockPath: string): string
	local succeeded, owner = pcall(fs.readFileToString, path.join(lockPath, "owner"))
	return if succeeded then owner elseif fs.exists(lockPath) then "unstamped" else "free"
end

-- Waits for this writer's turn and takes the lock. Writers queue by ticket and
-- take the lock in the order they arrived, so a writer can't keep losing the
-- lock to ones that came after it.
local function acquire(dir: string): string
	local lockPath = tostring(path.join(dir, fileNames.lock))
	local queuePath = tostring(path.join(dir, fileNames.lockQueue))
	ensureDirectory(queuePath)

	local ticketPath, ticket = takeTicket(queuePath)
	local succeeded, result = pcall(function(): string
		local seen = ""
		local stillSince = time.now()
		local checkedFrontAt = time.now()

		while true do
			local front = listTickets(queuePath)[1]
			local owner = readOwner(lockPath)

			if front == ticket and claim(lockPath) then
				stamp(lockPath)
				return lockPath
			end

			-- Reclaim a lock left behind by a writer that crashed.
			if owner ~= "free" and isLockAbandoned(lockPath) then
				removeDirectory(lockPath)
				continue
			end

			local state = `{owner}/{front}`

			if state ~= seen then
				seen = state
				stillSince = time.now()
				checkedFrontAt = time.now()
			end

			-- Drop the ticket of a writer that crashed while waiting, once it
			-- has sat at the front of the queue with the lock free.
			if front ~= ticket and owner == "free" and time.since(checkedFrontAt) > STALLED_TICKET_SECONDS then
				checkedFrontAt = time.now()

				if isTicketAbandoned(tostring(path.join(queuePath, tostring(front)))) then
					removeDirectory(tostring(path.join(queuePath, tostring(front))))
					continue
				end
			end

			assert(time.since(stillSince) < LOCK_TIMEOUT_SECONDS, `timed out waiting for {lockPath}`)
			task.wait(POLL_SECONDS)
		end
	end)

	removeDirectory(ticketPath)

	if not succeeded then
		error(result, 0)
	end

	return result
end

-- Runs `run` while holding the workspace lock, and releases it whether or not
-- `run` fails. Every write to a workspace goes through here: the data file, and
-- the files beside it such as the log.
local function runWithLock<T>(dir: string, run: () -> T): T
	ensureDirectory(dir)

	local lockPath = acquire(dir)
	local succeeded, result = pcall(run)
	removeDirectory(lockPath)

	if not succeeded then
		error(result, 0)
	end

	return result
end

return runWithLock
