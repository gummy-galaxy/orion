local storeTypes = require("@root/storage/types")

-- The writer of the command running in this process, which every write it
-- makes records in the revision log. `runAsWriter` sets it.
local state: { current: storeTypes.Writer? } = { current = nil }

return state
