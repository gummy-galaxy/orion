local findRef = require("@root/refs/findRef")
local getGithubKey = require("@root/refs/getGithubKey")
local githubTypes = require("@root/github/types")
local isNote = require("@root/graph/isNote")
local types = require("@root/types")

type PullState = githubTypes.PullState
type Doc = types.Doc
type Item = types.Item

-- Cards whose branch ref names the pull request's head branch in its repository. A card that
-- already tracks a pull request, is done, or is a note doesn't take another one.
local function findBranchCards(doc: Doc, pull: PullState): { Item }
	local cards: { Item } = {}

	if pull.headRefName == "" then
		return cards
	end

	local key = getGithubKey(pull.owner, pull.name, `@{pull.headRefName}`, pull.host)

	for _, item in doc.nodes do
		if
			item.type == "task"
			and not isNote(item)
			and item.data.status ~= "done"
			and findRef(item, "branch", key)
			and not findRef(item, "pull")
		then
			table.insert(cards, item)
		end
	end

	return cards
end

return findBranchCards
