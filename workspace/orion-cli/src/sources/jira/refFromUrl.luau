local types = require("@root/types")

type ResolvedRef = types.ResolvedRef
type Source = types.Source

local JIRA_KEY = "^%u[%u%d_]*%-%d+$"

local function refFromUrl(url: string, sources: { Source }): ResolvedRef?
	for _, source in sources do
		local browse = source.browse

		if source.kind == "jira" and browse then
			local prefix = `{browse}/`

			if url:sub(1, #prefix):lower() == prefix:lower() then
				local key = url:sub(#prefix + 1)

				if key:match(JIRA_KEY) then
					return { ref = { source = source.id, kind = "issue", type = "step", key = key, url = url } }
				end
			end
		end
	end

	return nil
end

return refFromUrl
