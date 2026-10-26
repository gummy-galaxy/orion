local json = require("@std/json")

local decodeDocObject = require("@root/store/decodeDocObject")
local types = require("@root/types")

type Doc = types.Doc

-- Reads a whole canvas saved as one JSON file, such as a backup, into a
-- document.
local function decodeDoc(text: string): Doc
	local root = json.asObject(json.deserialize(text) :: json.Value)
	assert(root, "Orion data must be a JSON object")
	return decodeDocObject(root)
end

return decodeDoc
