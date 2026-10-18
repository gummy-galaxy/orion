local encodeDoc = require("@root/store/encodeDoc")
local runWithLock = require("@root/store/runWithLock")
local types = require("@root/types")
local writeDocFile = require("@root/store/writeDocFile")

type Doc = types.Doc

-- Writes a whole document as it is, without bumping its revision. Used to seed data and in tests.
local function writeDoc(dir: string, doc: Doc)
	runWithLock(dir, function(): nil
		writeDocFile(dir, encodeDoc(doc))
		return nil
	end)
end

return writeDoc
