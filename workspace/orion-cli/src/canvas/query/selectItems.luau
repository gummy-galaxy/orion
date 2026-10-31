local queryItems = require("@root/canvas/query/queryItems")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

local function selectItems(doc: Doc, expression: string, includeDone: boolean, now: string?): { Item }
	return queryItems(doc, { where = expression, includeDone = includeDone, now = now }).items
end

return selectItems
