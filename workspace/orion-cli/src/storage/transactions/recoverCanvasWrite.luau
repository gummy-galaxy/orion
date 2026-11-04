local archivist = require("@pkg/Archivist@v0.2.0")
local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local applyCanvasWrite = require("@root/storage/transactions/applyCanvasWrite")
local fileNames = require("@root/fileNames")
local finishCanvasWrite = require("@root/storage/transactions/finishCanvasWrite")
local hasSqlite = require("@root/storage/index/hasSqlite")
local openCanvasIndex = require("@root/storage/index/openCanvasIndex")
local runSqlite = require("@root/storage/index/runSqlite")
local storeTypes = require("@root/storage/types")

type CanvasWrite = storeTypes.CanvasWrite

local logger = archivist.getLogger("orion.index")

local function getWrite(batch: unknown): CanvasWrite
	local object = assert(json.asObject(json.deserialize(batch :: string) :: json.Value), "a journaled write is broken")
	local writes: { [string]: string } = {}
	local removes: { string } = {}

	for file, text in json.asObject(object.writes) or {} do
		if type(file) == "string" and type(text) == "string" then
			writes[file] = text
		end
	end

	for _, file in json.asArray(object.removes) or {} do
		if type(file) == "string" then
			table.insert(removes, file)
		end
	end

	return { writes = writes, removes = removes }
end

--[[
	Finishes a write that stopped partway, such as one whose process was killed.
	Callers hold the lock, so a write marker still down belongs to a writer
	that's gone. Each operation the journal still has unfinished is put in place
	again from the start, in order, which leaves the canvas as it is after that
	write. Without a journaled operation, no file of the write moved yet, so the
	canvas is whole and only the marker goes.
]]
local function recoverCanvasWrite(dir: string)
	local marker = path.join(dir, fileNames.pendingWrite)

	if not fs.exists(marker) then
		return
	end

	if hasSqlite() then
		local rows =
			runSqlite(openCanvasIndex(dir), "SELECT id, batch FROM operations WHERE finishedAt IS NULL ORDER BY id;")

		for _, value in rows do
			local row = json.asObject(value) :: json.Object
			local id = row.id :: number
			local write = getWrite(row.batch)
			finishCanvasWrite(dir, id, applyCanvasWrite(dir, write))
			logger.warn("replayed unfinished write", id, "to", dir, "with", #write.removes, "removals")
		end
	end

	fs.remove(marker)
end

return recoverCanvasWrite
