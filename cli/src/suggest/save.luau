local convertToJson = require("@root/suggest/convertToJson")
local suggestTypes = require("@root/suggest/types")
local types = require("@root/types")

type Doc = types.Doc
type Result = suggestTypes.Result

local function save(doc: Doc, result: Result)
	doc.suggestions = convertToJson(result)
end

return save
