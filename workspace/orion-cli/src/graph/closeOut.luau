local getItem = require("@root/graph/getItem")
local getStateMeaning = require("@root/cardTypes/getStateMeaning")
local isWork = require("@root/graph/isWork")
local types = require("@root/types")

type Doc = types.Doc

-- Closes out a card finished in the app, so it lands its Done stamp at once
-- instead of waiting. Unlike closeChain, the waiting cards chained to it keep
-- waiting. markCelebrations reads `celebrate = false` as closed out and drops
-- it.
local function closeOut(doc: Doc, id: string)
	local item = getItem(doc, id)
	assert(isWork(item), `"{id}" isn't a work item, so it has nothing to close out`)
	assert(getStateMeaning(item) == "done", `"{id}" isn't done yet; finish it before closing it out`)

	item.data.celebrate = false
end

return closeOut
