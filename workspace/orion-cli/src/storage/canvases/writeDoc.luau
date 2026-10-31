local encodeDocObject = require("@root/storage/files/encodeDocObject")
local readCanvasFiles = require("@root/storage/files/readCanvasFiles")
local recoverCanvasWrite = require("@root/storage/transactions/recoverCanvasWrite")
local runWithLock = require("@root/storage/transactions/runWithLock")
local types = require("@root/types")
local writeCanvasFiles = require("@root/storage/files/writeCanvasFiles")

type Doc = types.Doc

-- Writes a whole document as it is, without bumping its revision. Used to seed
-- data and in tests. Files that can't be read are replaced without a backup.
local function writeDoc(dir: string, doc: Doc)
	runWithLock(dir, function(): nil
		recoverCanvasWrite(dir)
		local succeeded, previous = pcall(readCanvasFiles, dir, true)
		writeCanvasFiles(dir, encodeDocObject(doc), if succeeded then previous else nil)
		return nil
	end)
end

return writeDoc
