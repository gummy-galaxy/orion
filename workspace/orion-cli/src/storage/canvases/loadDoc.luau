local createEmptyDoc = require("@root/storage/canvases/createEmptyDoc")
local readDoc = require("@root/storage/canvases/readDoc")
local types = require("@root/types")

type Doc = types.Doc

-- A workspace without a data file reads as empty; the first change writes it.
local function loadDoc(dir: string): Doc
	return readDoc(dir) or createEmptyDoc()
end

return loadDoc
