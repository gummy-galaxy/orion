local fs = require("@std/fs")
local path = require("@std/path")

local decodeFocus = require("@root/store/decodeFocus")
local fileNames = require("@root/fileNames")
local types = require("@root/types")

type Focus = types.Focus

-- Nil when the app isn't open, or caught the file mid-replace.
local function readFocus(dir: string): Focus?
	local file = path.join(dir, fileNames.focus)

	if not fs.exists(file) then
		return nil
	end

	local succeeded, focus = pcall(function()
		return decodeFocus(fs.readFileToString(file))
	end)

	return if succeeded then focus else nil
end

return readFocus
