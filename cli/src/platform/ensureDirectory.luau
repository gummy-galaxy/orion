local fs = require("@std/fs")
local path = require("@std/path")

-- Creates a folder and its parents unless it's already there. Another process
-- can create it between the check and the create, which only counts as a
-- failure if the folder still doesn't exist afterward.
local function ensureDirectory(dir: path.Pathlike)
	local failure: unknown = nil

	-- A parent made by another process at the same moment can fail one attempt, so try twice.
	for _ = 1, 2 do
		if fs.exists(dir) then
			return
		end

		local succeeded, message = pcall(function()
			fs.createDirectory(dir, { makeParents = true })
		end)

		if succeeded then
			return
		end

		failure = message
	end

	if not fs.exists(dir) then
		error(failure, 0)
	end
end

return ensureDirectory
