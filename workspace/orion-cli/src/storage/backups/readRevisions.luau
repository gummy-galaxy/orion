local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")

local fileNames = require("@root/fileNames")
local storeTypes = require("@root/storage/types")

type RevisionEntry = storeTypes.RevisionEntry

-- Reads the canvas's revision log by revision. A line that doesn't parse is
-- skipped, and a later line for a revision replaces an earlier one.
local function readRevisions(dir: string): { [number]: RevisionEntry }
	local file = path.join(dir, fileNames.backups, fileNames.revisions)
	local entries: { [number]: RevisionEntry } = {}

	if not fs.exists(file) then
		return entries
	end

	for line in fs.readFileToString(file):gmatch("[^\n]+") do
		local parsed, value = pcall(json.deserialize, line)
		local object = if parsed then json.asObject(value :: json.Value) else nil

		if object and type(object.revision) == "number" and type(object.time) == "string" then
			entries[object.revision :: number] = {
				revision = object.revision :: number,
				time = object.time :: string,
				by = if type(object.by) == "string" then object.by :: string else "app",
				command = if type(object.command) == "string" then object.command :: string else nil,
			}
		end
	end

	return entries
end

return readRevisions
