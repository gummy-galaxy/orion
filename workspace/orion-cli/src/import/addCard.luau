local adapterTypes = require("@root/adapters/types")
local addItem = require("@root/graph/addItem")
local attachRef = require("@root/graph/attachRef")
local types = require("@root/types")

type Record = adapterTypes.Record
type Doc = types.Doc
type Item = types.Item

-- Adds a card for a looked-up record, shaped the way ingest shapes the same record.
local function addCard(doc: Doc, record: Record, groupId: string?): Item
	local item = addItem(doc, record.label, {
		group = groupId,
		repo = record.repo,
		status = record.status or record.createStatus or "todo",
		who = record.who or record.createWho,
	})
	attachRef(doc, item.id, { ref = record.ref, repo = record.repo })
	return item
end

return addCard
