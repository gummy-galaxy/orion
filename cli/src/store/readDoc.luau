local fs = require("@std/fs")

local decodeDoc = require("@root/store/decodeDoc")
local getDocPath = require("@root/store/getDocPath")
local types = require("@root/types")

type Doc = types.Doc

-- Nil when the workspace has no data file yet.
local function readDoc(dir: string): Doc?
	local file = getDocPath(dir)

	if not fs.exists(file) then
		return nil
	end

	return decodeDoc(fs.readFileToString(file))
end

return readDoc
