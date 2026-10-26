local fs = require("@std/fs")
local process = require("@std/process")

-- Identifies the executable this process runs from. A rebuild or a replaced app
-- bundle changes it, and a missing file returns nil.
local function getBinaryFingerprint(): string?
	local ok, metadata = pcall(fs.metadata, process.execPath())

	if not ok then
		return nil
	end

	return `{metadata.size}:{tostring(metadata.modified)}`
end

return getBinaryFingerprint
