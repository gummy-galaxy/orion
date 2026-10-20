local json = require("@std/json")

local indexStatements = require("@root/store/indexStatements")
local openCanvasIndex = require("@root/store/openCanvasIndex")
local runSqlite = require("@root/sqlite/runSqlite")

-- How many finished operations the journal keeps for looking into a problem.
local KEPT_OPERATIONS = 20

local FINISH = [[
BEGIN IMMEDIATE;
UPDATE operations SET finishedAt = strftime('%%Y-%%m-%%dT%%H:%%M:%%fZ', 'now') WHERE id = %d;
CREATE TEMP TABLE fresh AS
	SELECT written.key AS path, stamp.value AS mtime, written.value AS text
	FROM json_each((SELECT batch FROM operations WHERE id = %d), '$.writes') AS written
	JOIN json_each((SELECT value FROM batch)) AS stamp ON stamp.key = written.key;
DELETE FROM files
	WHERE path IN (SELECT value FROM json_each((SELECT batch FROM operations WHERE id = %d), '$.removes'));
]]

local PRUNE = [[
DELETE FROM operations WHERE finishedAt IS NOT NULL AND id <= %d;
COMMIT;
]]

--[[
	Marks a journaled write finished once every file is in place, and records the files it wrote in the index with
	the times `stamps` gives them, so the next read doesn't open them again and the index knows what Orion wrote.
]]
local function finishCanvasWrite(dir: string, id: number, stamps: { [string]: number })
	local script = FINISH:format(id, id, id) .. indexStatements.upsertFresh .. PRUNE:format(id - KEPT_OPERATIONS)
	local batch = json.object({})

	for file, stamp in stamps do
		batch[file] = stamp
	end

	runSqlite(openCanvasIndex(dir), script, batch)
end

return finishCanvasWrite
