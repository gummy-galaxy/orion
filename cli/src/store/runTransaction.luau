local encodeDoc = require("@root/store/encodeDoc")
local getRecordedStatuses = require("@root/graph/getRecordedStatuses")
local loadDoc = require("@root/store/loadDoc")
local markCelebrations = require("@root/graph/markCelebrations")
local runWithLock = require("@root/store/runWithLock")
local types = require("@root/types")
local writeDocFile = require("@root/store/writeDocFile")

type Doc = types.Doc

-- Reads the latest data under the lock, applies `mutate`, and writes the next revision.
local function runTransaction(dir: string, mutate: (Doc) -> ()): Doc
	return runWithLock(dir, function(): Doc
		local doc = loadDoc(dir)
		local previous = getRecordedStatuses(doc)
		mutate(doc)
		markCelebrations(doc, previous)
		doc.revision += 1
		writeDocFile(dir, encodeDoc(doc))

		return doc
	end)
end

return runTransaction
