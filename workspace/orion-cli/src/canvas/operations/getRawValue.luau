local types = require("@root/types")

type Doc = types.Doc

-- A top-level value the CLI doesn't model, such as the sticker list, which the
-- document keeps as it was read.
local function getRawValue(doc: Doc, key: string): any
	if doc.raw == nil then
		return nil
	end

	return doc.raw[key]
end

return getRawValue
