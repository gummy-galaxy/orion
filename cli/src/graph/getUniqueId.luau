local findItem = require("@root/graph/findItem")
local types = require("@root/types")

type Doc = types.Doc

-- The base id when it's free, or the base with the first number suffix that is.
local function getUniqueId(doc: Doc, base: string): string
	if not findItem(doc, base) then
		return base
	end

	local suffix = 2

	while findItem(doc, `{base}-{suffix}`) do
		suffix += 1
	end

	return `{base}-{suffix}`
end

return getUniqueId
