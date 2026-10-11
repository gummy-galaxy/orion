local types = require("@lib/types")

type Run = types.Run

-- Reads the output of a jq filter that prints one run as `id`, `status`, and `conclusion` separated by tabs. Empty
-- output means there is no run.
local function parseLatestRun(output: string): Run?
	local id, status, conclusion = string.match(output, "^(%d+)\t([^\t]+)\t([^\n]*)\n?$")

	if not id or not status or not conclusion then
		return nil
	end

	return {
		id = id,
		status = status,
		conclusion = if conclusion ~= "" then conclusion else nil,
	}
end

return parseLatestRun
