local types = require("@root/types")

type Ref = types.Ref

-- Identifies a ref the way findRef matches it: its kind and a case-insensitive
-- key.
local function getRefKey(ref: Ref): string
	return `{ref.kind}:{ref.key:lower()}`
end

return getRefKey
