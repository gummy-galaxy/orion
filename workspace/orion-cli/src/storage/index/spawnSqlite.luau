local archivist = require("@pkg/Archivist@v0.2.0")
local fs = require("@std/fs")
local json = require("@std/json")
local process = require("@std/process")
local time = require("@std/time")

local quoteSqlString = require("@root/storage/index/quoteSqlString")
local sqliteTypes = require("@root/storage/index/types")

type SqliteFailure = sqliteTypes.SqliteFailure

local logger = archivist.getLogger("orion.sqlite")

-- How long a statement waits on another process's write before it fails.
local BUSY_TIMEOUT_MS = 5000

-- SQLite's result codes for a file that isn't a database or a database that's
-- damaged.
local CORRUPT_CODES = { ["(11)"] = true, ["(26)"] = true }

local batchSequence = 0

local function fail(message: string, isCorrupt: boolean): never
	local failure: SqliteFailure = { message = message, isCorrupt = isCorrupt }
	error(failure, 0)
end

local function isCorrupt(stderr: string): boolean
	for code in stderr:gmatch("%(%d+%)") do
		if CORRUPT_CODES[code] then
			return true
		end
	end

	return stderr:find("database disk image is malformed", 1, true) ~= nil
		or stderr:find("file is not a database", 1, true) ~= nil
end

--[[
	Runs `sql` against the database at `database` through the `sqlite3` command
	in the given output mode, such as `-json`, and returns what it printed. With
	`batch`, the statements can read it as one JSON string from the `batch`
	table's `value` column and unpack it with `json_each()`. The batch goes
	through a file rather than the command line, which caps one argument at 128
	KB on Linux.

	Raises a `SqliteFailure`, whose `isCorrupt` says the database needs to be
	rebuilt, and raises the spawn error when `sqlite3` isn't installed.
]]
local function spawnSqlite(database: string, sql: string, mode: string, batch: json.Value?): string
	local started = time.now()
	local batchFile: string? = nil
	local script = sql

	if batch ~= nil then
		batchSequence += 1
		batchFile = `{database}.batch.{process.pid()}.{batchSequence}.json`
		fs.writeStringToFile(batchFile :: string, json.serialize(batch))
		script =
			`CREATE TEMP TABLE batch AS SELECT CAST(readfile({quoteSqlString(batchFile :: string)}) AS TEXT) AS value;\n{sql}`
	end

	local succeeded, result = pcall(function()
		return process.run({ "sqlite3", "-bail", mode, "-cmd", `.timeout {BUSY_TIMEOUT_MS}`, database, script })
	end)

	if batchFile then
		pcall(fs.remove, batchFile)
	end

	if not succeeded then
		error(result, 0)
	end

	local elapsed = math.floor(time.since(started) * 1000)

	if not result.ok then
		local message = result.stderr:gsub("%s+$", "")
		logger.warn("query on", database, "failed after", elapsed, "ms:", message)
		fail(`sqlite3 failed on {database}: {message}`, isCorrupt(message))
	end

	logger.debug("query on", database, "took", elapsed, "ms and printed", #result.stdout, "bytes")

	return result.stdout
end

return spawnSqlite
