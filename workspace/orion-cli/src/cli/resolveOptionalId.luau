local resolveId = require("@root/query/resolveId")
local types = require("@root/types")

type Doc = types.Doc

-- Resolves an optional id or selector, such as a --group, --after, or --before value.
local function resolveOptionalId(doc: Doc, input: string?): string?
	return if input then resolveId(doc, input) else nil
end

return resolveOptionalId
