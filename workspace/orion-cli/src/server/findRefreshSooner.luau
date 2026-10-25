local findInView = require("@root/graph/findInView")
local types = require("@root/types")

type Doc = types.Doc
type Focus = types.Focus

--[[
	The ids of the cards the background refresh keeps on its faster cadence. For now they're the cards in view; watched
	cards (#232) join this same set rather than adding a cadence of their own.
]]
local function findRefreshSooner(doc: Doc, focus: Focus?): { [string]: boolean }
	return findInView(doc, focus)
end

return findRefreshSooner
