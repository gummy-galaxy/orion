local json = require("@std/json")

local hasSqlite = require("@root/storage/index/hasSqlite")
local openCanvasIndex = require("@root/storage/index/openCanvasIndex")
local runSqlite = require("@root/storage/index/runSqlite")
local storeTypes = require("@root/storage/types")

type CanvasWrite = storeTypes.CanvasWrite

-- Any operation still unfinished here outlived its marker, which a writer only
-- lifts after finishing, so it's stale: replaying it later would undo the
-- writes since.
local JOURNAL = [[
BEGIN IMMEDIATE;
UPDATE operations SET finishedAt = strftime('%%Y-%%m-%%dT%%H:%%M:%%fZ', 'now'), isAbandoned = 1
	WHERE finishedAt IS NULL;
INSERT INTO operations (revision, startedAt, batch)
	VALUES (%s, strftime('%%Y-%%m-%%dT%%H:%%M:%%fZ', 'now'), (SELECT value FROM batch));
SELECT last_insert_rowid() AS id;
COMMIT;
]]

--[[
	Records a write in the index's operations table before any of its files move
	into place, and returns the operation's id, or nil without `sqlite3`.
	Callers hold the lock and have put the write marker down, so a write that
	stops partway leaves both the marker and the operation for
	`recoverCanvasWrite` to finish.
]]
local function journalCanvasWrite(dir: string, write: CanvasWrite, revision: number?): number?
	if not hasSqlite() then
		return nil
	end

	local writes = json.object({})
	local removes: json.Array = {}

	for file, text in write.writes do
		writes[file] = text
	end

	for _, file in write.removes do
		table.insert(removes, file)
	end

	local batch = json.object({ writes = writes, removes = removes })
	local rows = runSqlite(openCanvasIndex(dir), JOURNAL:format(if revision then tostring(revision) else "NULL"), batch)
	local row = json.asObject(rows[#rows])
	local id = if row then row.id else nil

	return assert(if type(id) == "number" then id else nil, `the index of {dir} didn't record the write`)
end

return journalCanvasWrite
