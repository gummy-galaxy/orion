local loadDoc = require("@root/storage/canvases/loadDoc")
local raiseFailure = require("@root/common/errors/raiseFailure")
local runTransaction = require("@root/storage/transactions/runTransaction")
local types = require("@root/types")

type Doc = types.Doc

local function runEdit(dir: string, dryRun: boolean, ifRevision: number?, mutate: (Doc) -> ()): (Doc, number)
	local baseRevision = 0
	local function apply(doc: Doc)
		baseRevision = doc.revision

		if ifRevision ~= nil and ifRevision ~= baseRevision then
			raiseFailure("revision-conflict", `revision changed: expected {ifRevision}, current {baseRevision}`)
		end

		mutate(doc)
	end

	if dryRun then
		local doc = loadDoc(dir)
		apply(doc)
		return doc, baseRevision
	end

	local doc = runTransaction(dir, apply)
	return doc, baseRevision
end

return runEdit
