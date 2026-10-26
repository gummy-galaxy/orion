local archivist = require("@archivist")
local fs = require("@std/fs")
local json = require("@std/json")

local getIndexPath = require("@root/store/getIndexPath")
local runSqlite = require("@root/sqlite/runSqlite")

local logger = archivist.getLogger("orion.index")

-- Bump when the tables change. An index of any other version is deleted and
-- built again from the files.
local SCHEMA_VERSION = 2

local SCHEMA = [[
BEGIN IMMEDIATE;
CREATE TABLE IF NOT EXISTS files (
	path TEXT PRIMARY KEY,
	folder TEXT NOT NULL,
	entry TEXT,
	isValid INTEGER NOT NULL,
	mtime INTEGER NOT NULL,
	checked INTEGER NOT NULL,
	hash TEXT NOT NULL,
	text TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS filesByEntry ON files (folder, entry);
CREATE TABLE IF NOT EXISTS operations (
	id INTEGER PRIMARY KEY,
	revision INTEGER,
	startedAt TEXT NOT NULL,
	finishedAt TEXT,
	isAbandoned INTEGER NOT NULL DEFAULT 0,
	batch TEXT NOT NULL
);
PRAGMA user_version = %d;
COMMIT;
]]

-- Index folders this process has already checked, so each opens with one query
-- per process.
local opened: { [string]: boolean } = {}

local function remove(database: string)
	for _, suffix in { "", "-wal", "-shm" } do
		if fs.exists(database .. suffix) then
			fs.remove(database .. suffix)
		end
	end
end

local function getVersion(database: string): number
	local rows = runSqlite(database, "PRAGMA journal_mode = WAL; PRAGMA user_version;")
	local version = 0

	for _, row in rows do
		local object = json.asObject(row)

		if object and type(object.user_version) == "number" then
			version = object.user_version
		end
	end

	return version
end

local function prepare(database: string)
	local version = getVersion(database)

	if version == SCHEMA_VERSION then
		return
	end

	-- A new database reads as version 0, and so does one with tables Orion
	-- didn't make, which the schema then fails on.
	if version == 0 and pcall(runSqlite, database, SCHEMA:format(SCHEMA_VERSION), nil) then
		return
	end

	logger.info("rebuilding", database, "from version", version, "as version", SCHEMA_VERSION)
	remove(database)
	getVersion(database)
	runSqlite(database, SCHEMA:format(SCHEMA_VERSION))
end

--[[
	Opens a canvas folder's index, creating its tables when it has none, and
	returns the database's path. An index that is damaged, isn't a database, or
	was made for another schema is deleted and built again, since the files hold
	everything it does. With `shouldRebuild`, the index is deleted first.
]]
local function openCanvasIndex(dir: string, shouldRebuild: boolean?): string
	local database = getIndexPath(dir)

	if shouldRebuild then
		opened[dir] = nil
		remove(database)
	end

	if opened[dir] and fs.exists(database) then
		return database
	end

	local succeeded, failure = pcall(prepare, database)

	if not succeeded then
		if type(failure) ~= "table" or not (failure :: any).isCorrupt then
			error(failure, 0)
		end

		logger.warn("rebuilding", database, "after", (failure :: any).message)
		remove(database)
		prepare(database)
	end

	opened[dir] = true

	return database
end

return openCanvasIndex
