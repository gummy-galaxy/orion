local createEmptyDoc = require("@root/store/createEmptyDoc")
local decodeDocObject = require("@root/store/decodeDocObject")
local encodeDocObject = require("@root/store/encodeDocObject")
local getRecordedStatuses = require("@root/graph/getRecordedStatuses")
local markCelebrations = require("@root/graph/markCelebrations")
local readCanvasFiles = require("@root/store/readCanvasFiles")
local runWithLock = require("@root/store/runWithLock")
local types = require("@root/types")
local writeCanvasFiles = require("@root/store/writeCanvasFiles")

type Doc = types.Doc

-- Reads the latest data under the lock, applies `mutate`, and writes the next revision.
local function runTransaction(dir: string, mutate: (Doc) -> ()): Doc
	return runWithLock(dir, function(): Doc
		local snapshot = readCanvasFiles(dir, true)
		local doc = if snapshot then decodeDocObject(snapshot.document) else createEmptyDoc()
		local previous = getRecordedStatuses(doc)
		mutate(doc)
		markCelebrations(doc, previous)
		doc.revision += 1
		writeCanvasFiles(dir, encodeDocObject(doc), snapshot)

		return doc
	end)
end

return runTransaction
