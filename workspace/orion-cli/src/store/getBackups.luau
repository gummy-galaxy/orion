local fs = require("@std/fs")
local path = require("@std/path")

local fileNames = require("@root/fileNames")
local storeTypes = require("@root/store/types")

type Backup = storeTypes.Backup

-- Lists a workspace's backups, newest first. Files that aren't named like a
-- backup are left out.
local function getBackups(dir: string): { Backup }
	local folder = path.join(dir, fileNames.backups)
	local found: { Backup } = {}

	if not fs.exists(folder) then
		return found
	end

	for _, entry in fs.listDirectory(folder) do
		local revision, time = entry.name:match("^orion%-r(%d+)%-(%d%d%d%d%d%d%d%dT%d%d%d%d%d%dZ)%.json$")

		if entry.type == "file" and revision and time then
			local file = tostring(path.join(folder, entry.name))
			table.insert(found, {
				revision = tonumber(revision) :: number,
				time = time,
				size = fs.metadata(file).size,
				file = file,
			})
		end
	end

	table.sort(found, function(a: Backup, b: Backup)
		return if a.time == b.time then a.file > b.file else a.time > b.time
	end)

	return found
end

return getBackups
