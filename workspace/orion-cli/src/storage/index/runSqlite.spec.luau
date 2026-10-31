local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local ensureDirectory = require("@root/common/platform/ensureDirectory")
local runSqlite = require("@root/storage/index/runSqlite")
local testing = require("@root/testing")

local function createDatabase(name: string): string
	local dir = testing.directory(name)
	ensureDirectory(dir)
	return tostring(path.join(dir, "test.sqlite"))
end

test.case("runSqlite returns the rows of every statement that has any", function(assert)
	local database = createDatabase("sqlite-rows")
	local rows =
		runSqlite(database, "CREATE TABLE t (a); INSERT INTO t VALUES (1), (2); SELECT a FROM t; SELECT 'x\ny' AS b;")

	assert.eq(#rows, 3)
	assert.eq((json.asObject(rows[2]) :: json.Object).a, 2)
	assert.eq((json.asObject(rows[3]) :: json.Object).b, "x\ny")
	assert.eq(#runSqlite(database, "SELECT a FROM t WHERE a > 5;"), 0)
end)

test.case("runSqlite passes a batch as one JSON string", function(assert)
	local database = createDatabase("sqlite-batch")
	local batch: json.Array = { json.object({ name = "it's" }), json.object({ name = string.rep("long ", 40000) }) }
	local rows = runSqlite(
		database,
		"SELECT json_extract(value, '$.name') AS name FROM json_each((SELECT value FROM batch)) ORDER BY key;",
		batch
	)

	assert.eq(#rows, 2)
	assert.eq((json.asObject(rows[1]) :: json.Object).name, "it's")
	assert.eq(#((json.asObject(rows[2]) :: json.Object).name :: string), 200000)
	assert.eq(#fs.listDirectory(path.dirname(database) :: any), 1)
end)

test.case("runSqlite raises a failure that says whether the database is damaged", function(assert)
	local database = createDatabase("sqlite-failure")
	local succeeded, failure = pcall(runSqlite, database, "SELECT * FROM missing;", nil)
	assert.eq(succeeded, false)
	assert.strContains((failure :: any).message, "no such table")
	assert.eq((failure :: any).isCorrupt, false)

	fs.writeStringToFile(database, string.rep("not a database ", 100))
	succeeded, failure = pcall(runSqlite, database, "SELECT count(*) FROM sqlite_master;", nil)
	assert.eq(succeeded, false)
	assert.eq((failure :: any).isCorrupt, true)
end)
