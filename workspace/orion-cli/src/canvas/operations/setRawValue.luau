local json = require("@std/json")

local copyValue = require("@root/canvas/operations/copyValue")
local types = require("@root/types")

type Doc = types.Doc

-- Sets or clears a top-level value the CLI doesn't model. Clearing a value that
-- was never set does nothing.
local function setRawValue(doc: Doc, key: string, value: any)
	if doc.raw == nil and value == nil then
		return
	end

	local raw: json.Object = doc.raw or json.object({})
	doc.raw = raw
	raw[key] = copyValue(value)
end

return setRawValue
