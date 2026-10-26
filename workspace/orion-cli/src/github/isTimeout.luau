-- GitHub answers a GraphQL query that runs past its time limit with a bare 502
-- or 504, or with an error that names a timeout. A smaller query usually fits.
local function isTimeout(message: string): boolean
	local text = message:lower()
	return text:find("http 50[24]") ~= nil
		or text:find("timeout", 1, true) ~= nil
		or text:find("timed out", 1, true) ~= nil
end

return isTimeout
