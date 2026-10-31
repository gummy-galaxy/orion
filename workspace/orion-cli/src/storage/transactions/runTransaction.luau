local createEmptyDoc = require("@root/storage/canvases/createEmptyDoc")
local decodeDocObject = require("@root/storage/files/decodeDocObject")
local encodeDocObject = require("@root/storage/files/encodeDocObject")
local getRecordedStatuses = require("@root/canvas/items/getRecordedStatuses")
local markCelebrations = require("@root/canvas/items/markCelebrations")
local readCanvasFiles = require("@root/storage/files/readCanvasFiles")
local recoverCanvasWrite = require("@root/storage/transactions/recoverCanvasWrite")
local runWithLock = require("@root/storage/transactions/runWithLock")
local types = require("@root/types")
local writeCanvasFiles = require("@root/storage/files/writeCanvasFiles")

type Doc = types.Doc

-- Reads the latest data under the lock, applies `mutate`, and writes the next
-- revision.
local function runTransaction(dir: string, mutate: (Doc) -> ()): Doc
	return runWithLock(dir, function(): Doc
		recoverCanvasWrite(dir)
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
