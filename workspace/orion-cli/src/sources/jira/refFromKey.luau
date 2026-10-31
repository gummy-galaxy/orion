local types = require("@root/types")

type ResolvedRef = types.ResolvedRef
type Source = types.Source

local JIRA_KEY = "^%u[%u%d_]*%-%d+$"

local function refFromKey(key: string, source: Source): ResolvedRef?
	if not key:match(JIRA_KEY) then
		return nil
	end

	return {
		ref = {
			source = source.id,
			kind = "issue",
			type = "step",
			key = key,
			url = if source.browse then `{source.browse}/{key}` else nil,
		},
	}
end

return refFromKey
