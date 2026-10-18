local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")

local runWithLock = require("@root/store/runWithLock")
local testing = require("@root/testing")

local function leaveLock(dir: string, owner: string?, isOld: boolean)
	local lockPath = path.join(dir, "orion.lock")
	fs.createDirectory(lockPath, { makeParents = true })

	if owner then
		fs.writeStringToFile(path.join(lockPath, "owner"), owner)
	end

	if isOld then
		assert(process.run({ "touch", "-t", "202001010000", tostring(lockPath) }).ok, "could not age the lock")
	end
end

-- Above any operating system's highest process id, so it never names a live process.
local GONE_PROCESS_ID = 99999999

test.case("runWithLock holds the lock while it runs and returns what the run returns", function(assert)
	local dir = testing.directory("with-lock")
	local result = runWithLock(dir, function()
		assert.eq(fs.exists(path.join(dir, "orion.lock", "owner")), true)
		return "ran"
	end)

	assert.eq(result, "ran")
	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
end)

test.case("runWithLock releases the lock and rethrows when the run fails", function(assert)
	local dir = testing.directory("with-lock-failure")
	assert.throwsWith("nope", function()
		runWithLock(dir, function(): nil
			error("nope", 0)
		end)
	end)

	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
end)

test.case("runWithLock reclaims a stale lock whose writer is gone", function(assert)
	local dir = testing.directory("stale-owner")
	leaveLock(dir, `{GONE_PROCESS_ID} {os.time() - 60}`, false)

	assert.eq(
		runWithLock(dir, function()
			return true
		end),
		true
	)
	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
end)

test.case("runWithLock waits out a slow writer that still holds the lock", function(assert)
	local dir = testing.directory("slow-owner")
	local didRun = false
	leaveLock(dir, `{process.pid()} {os.time() - 60}`, false)

	assert.throws(function()
		runWithLock(dir, function(): boolean
			didRun = true
			return didRun
		end)
	end)

	assert.eq(didRun, false)
	assert.eq(fs.exists(path.join(dir, "orion.lock")), true)
end)

test.case("runWithLock reclaims a lock held far past stale, since its process id may be reused", function(assert)
	local dir = testing.directory("ancient-owner")
	leaveLock(dir, `{process.pid()} {os.time() - 60 * 60}`, false)

	assert.eq(
		runWithLock(dir, function()
			return true
		end),
		true
	)
end)

test.case("runWithLock waits on a fresh lock whose writer hasn't stamped it yet", function(assert)
	local dir = testing.directory("fresh-ownerless")
	local didRun = false
	leaveLock(dir, nil, false)

	assert.throws(function()
		runWithLock(dir, function(): boolean
			didRun = true
			return didRun
		end)
	end)

	assert.eq(didRun, false)
end)

test.case("runWithLock reclaims an old lock left without an owner", function(assert)
	local dir = testing.directory("ownerless")
	leaveLock(dir, nil, true)

	assert.eq(
		runWithLock(dir, function()
			return true
		end),
		true
	)
	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
end)

test.case("runWithLock reclaims an old lock with an unreadable owner stamp", function(assert)
	local dir = testing.directory("blank-owner")
	leaveLock(dir, "", true)

	assert.eq(
		runWithLock(dir, function()
			return true
		end),
		true
	)
	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
end)
