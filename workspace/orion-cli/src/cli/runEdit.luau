local loadDoc = require("@root/store/loadDoc")
local runTransaction = require("@root/store/runTransaction")
local types = require("@root/types")

type Doc = types.Doc

local function runEdit(dir: string, dryRun: boolean, ifRevision: number?, mutate: (Doc) -> ()): (Doc, number)
	local baseRevision = 0
	local function apply(doc: Doc)
		baseRevision = doc.revision
		assert(
			ifRevision == nil or ifRevision == baseRevision,
			`revision changed: expected {ifRevision}, current {baseRevision}`
		)
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
