local getUnix = require("@root/adapters/getUnix")

-- Collect functions take the same context as ingest, including a `since` date that only their searches read.
local function getSince(now: string): string
	return os.date("!%Y-%m-%d", getUnix(now) - 14 * 86400) :: string
end

return getSince
