local getGithubKey = require("@root/sources/github/refs/getGithubKey")
local types = require("@root/types")

type ResolvedRef = types.ResolvedRef
type Source = types.Source

local PUBLIC_HOST = "github.com"

local function refFromUrl(url: string, sources: { Source }): ResolvedRef?
	local host, owner, name, segment, number = url:match("^https://([%w%.%-]+)/([%w_.%-]+)/([%w_.%-]+)/(%a+)/(%d+)$")

	if not host or not owner or not name or not segment or not number then
		return nil
	end

	local kind = if segment == "pull" then "pull" elseif segment == "issues" then "issue" else nil

	if not kind then
		return nil
	end

	local lowerHost = host:lower()
	local configured: Source? = nil

	for _, source in sources do
		if source.kind == "github" and source.host and source.host:lower() == lowerHost then
			configured = source
			break
		end
	end

	-- Without a configured source, only github.com is known well enough to
	-- attach.
	if not configured and lowerHost ~= PUBLIC_HOST then
		return nil
	end

	return {
		ref = {
			source = if configured then configured.id else "github",
			kind = kind,
			type = if kind == "pull" then "pr" else "placeholder",
			key = getGithubKey(owner, name, `#{number}`, lowerHost),
			url = url,
		},
		repo = `{owner}/{name}`,
	}
end

return refFromUrl
