local githubTypes = require("@root/sources/github/types")
local isListed = require("@root/sources/github/pulls/isListed")
local types = require("@root/types")

type PullState = githubTypes.PullState
type Doc = types.Doc

-- Your own open pull requests only belong on a canvas whose GitHub sources
-- cover their repository. A canvas without GitHub sources takes them all.
local function isInSources(doc: Doc, pull: PullState): boolean
	local hasSources = false

	for _, source in doc.settings.sources do
		if source.kind ~= "github" or (source.host or "github.com") ~= "github.com" then
			continue
		end

		hasSources = true

		if
			isListed(source.owners, pull.owner)
			and (not source.include or isListed(source.include, pull.name))
			and not isListed(source.exclude, pull.name)
		then
			return true
		end
	end

	return not hasSources
end

return isInSources
