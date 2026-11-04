local archivist = require("@pkg/Archivist@v0.2.0")
local process = require("@std/process")

local logger = archivist.getLogger("orion.sqlite")

local isAvailable: boolean? = nil

-- Whether the `sqlite3` command can run here, checked once per process. Without
-- it, canvases are read from every file and writes aren't journaled.
local function hasSqlite(): boolean
	if isAvailable == nil then
		local succeeded, result = pcall(function()
			return process.run({ "sqlite3", "-version" })
		end)
		isAvailable = succeeded and result.ok

		if not isAvailable then
			logger.warn("sqlite3 can't run, so canvases are read from every file and writes aren't journaled")
		end
	end

	return isAvailable == true
end

return hasSqlite
