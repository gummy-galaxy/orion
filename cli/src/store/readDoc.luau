local decodeDocObject = require("@root/store/decodeDocObject")
local readCanvasFiles = require("@root/store/readCanvasFiles")
local types = require("@root/types")

type Doc = types.Doc

-- Nil when the canvas has no files yet.
local function readDoc(dir: string): Doc?
	local snapshot = readCanvasFiles(dir)
	return if snapshot then decodeDocObject(snapshot.document) else nil
end

return readDoc
