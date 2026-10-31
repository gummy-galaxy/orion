local json = require("@std/json")

local encodeDocObject = require("@root/storage/files/encodeDocObject")
local types = require("@root/types")

type Doc = types.Doc

-- The data file's text for a document.
local function encodeDoc(doc: Doc): string
	return json.serialize(encodeDocObject(doc), true)
end

return encodeDoc
