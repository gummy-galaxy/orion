local encodeDocObject = require("@root/store/encodeDocObject")
local readCanvasFiles = require("@root/store/readCanvasFiles")
local runWithLock = require("@root/store/runWithLock")
local types = require("@root/types")
local writeCanvasFiles = require("@root/store/writeCanvasFiles")

type Doc = types.Doc

-- Writes a whole document as it is, without bumping its revision. Used to seed data and in tests. Files that
-- can't be read are replaced without a backup.
local function writeDoc(dir: string, doc: Doc)
	runWithLock(dir, function(): nil
		local succeeded, previous = pcall(readCanvasFiles, dir)
		writeCanvasFiles(dir, encodeDocObject(doc), if succeeded then previous else nil)
		return nil
	end)
end

return writeDoc
