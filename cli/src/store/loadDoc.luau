local createEmptyDoc = require("@root/store/createEmptyDoc")
local readDoc = require("@root/store/readDoc")
local types = require("@root/types")

type Doc = types.Doc

-- A workspace without a data file reads as empty; the first change writes it.
local function loadDoc(dir: string): Doc
	return readDoc(dir) or createEmptyDoc()
end

return loadDoc
