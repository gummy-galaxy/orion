local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")
local task = require("@std/task")
local test = require("@std/test")

local buildTools = require("@root/cli/mcp/catalog/buildTools")
local cli = require("@root/cli")
local fileNames = require("@root/fileNames")
local loadDoc = require("@root/store/loadDoc")
local queueBehindLock = require("@root/cli/mcp/server/queueBehindLock")
local serve = require("@root/cli/mcp/server/serve")
local testing = require("@root/testing")

local need = assert
local TOOLS = buildTools(cli.describe())

-- Longer than the store waits for its lock, so a call made while the lock is
-- held times out at least once.
local HOLD_SECONDS = 5.2

local function addItem(id: number, title: string): string
	return json.serialize(json.object({
		jsonrpc = "2.0",
		id = id,
		method = "tools/call",
		params = json.object({ name = "orion_card_create", arguments = json.object({ label = title }) }),
	}))
end

-- Holds the canvas lock the way another Orion process would, until release is
-- called.
local function holdLock(dir: string): () -> ()
	local lockPath = path.join(dir, fileNames.lock)
	fs.createDirectory(dir, { makeParents = true })
	fs.createDirectory(lockPath)
	fs.writeStringToFile(path.join(lockPath, "owner"), `{process.pid()} {os.time()}`)

	return function()
		fs.removeDirectory(lockPath, { recursive = true })
	end
end

local function lockTimeout(dir: string): string
	return `timed out waiting for {path.join(dir, fileNames.lock)}`
end

test.case("overlapping write calls wait behind another process's lock and all apply", function(assert)
	local dir = testing.directory("mcp-queue-overlap")
	local run = queueBehindLock(function(argv: { string }, write: (string) -> ())
		cli.execute(argv, { dataDir = dir, write = write })
	end)
	local chunks = { `{addItem(1, "First")}\n{addItem(2, "Second")}\n{addItem(3, "Third")}\n` }
	local written: { string } = {}
	local release = holdLock(dir)

	task.delay(HOLD_SECONDS, release)

	serve(function()
		local chunk = table.remove(chunks, 1)

		if chunk == nil then
			error("end of file")
		end

		return chunk
	end, function(text: string)
		table.insert(written, text)
	end, TOOLS, run)

	assert.eq(#written, 3)

	for index, text in written do
		local answer = need(json.asObject(json.deserialize(text) :: json.Value))
		local result = need(json.asObject(answer.result))
		assert.eq(answer.id, index)
		assert.eq(result.isError, nil)
	end

	local labels: { string } = {}

	for _, node in loadDoc(dir).nodes do
		table.insert(labels, node.data.label :: string)
	end

	table.sort(labels)
	assert.eq(table.concat(labels, ","), "First,Second,Third")
end)

test.case("a call runs again after a lock timeout and keeps only the attempt that succeeds", function(assert)
	local attempts = 0
	local run = queueBehindLock(function(_argv: { string }, write: (string) -> ())
		attempts += 1
		write(`attempt {attempts}`)

		if attempts < 3 then
			error(lockTimeout("/canvas"))
		end
	end)
	local lines: { string } = {}

	run({ "card", "create", "Title" }, function(line: string)
		table.insert(lines, line)
	end)

	assert.eq(attempts, 3)
	assert.eq(table.concat(lines, "\n"), "attempt 3")
end)

test.case("a call that waits past the queue timeout fails with a clear error", function(assert)
	local attempts = 0
	local run = queueBehindLock(function()
		attempts += 1
		error(lockTimeout("/canvas"), 0)
	end, 0)

	local ok, message = pcall(run, { "card", "create", "Title" }, function() end)

	assert.eq(ok, false)
	assert.eq(attempts, 1)
	assert.strContains(tostring(message), "Gave up after waiting 0 seconds for another Orion process to release")
	assert.strContains(tostring(message), tostring(path.join("/canvas", fileNames.lock)))
	assert.strContains(tostring(message), "Nothing was changed; try the call again.")
end)

test.case("a call that fails for another reason fails at once", function(assert)
	local attempts = 0
	local run = queueBehindLock(function()
		attempts += 1
		error('no item with id "missing"', 0)
	end)

	local ok, message = pcall(run, { "card", "done", "missing" }, function() end)

	assert.eq(ok, false)
	assert.eq(attempts, 1)
	assert.eq(message, 'no item with id "missing"')
end)
