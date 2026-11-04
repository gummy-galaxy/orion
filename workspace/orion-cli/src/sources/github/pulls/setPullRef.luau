local findRef = require("@root/canvas/refs/findRef")
local getGithubId = require("@root/sources/github/refs/getGithubId")
local getGithubKey = require("@root/sources/github/refs/getGithubKey")
local getRecorded = require("@root/sources/github/pulls/getRecorded")
local githubTypes = require("@root/sources/github/types")
local setPullFacts = require("@root/sources/github/pulls/setPullFacts")
local setRef = require("@root/canvas/refs/setRef")
local types = require("@root/types")

type PullState = githubTypes.PullState
type Item = types.Item

local function setPullRef(item: Item, pull: PullState, source: string, viewer: string, checkedAt: string)
	local details = getRecorded(pull, viewer, checkedAt)
	local existing = findRef(item, "pull", getGithubKey(pull.owner, pull.name, `#{pull.number}`, pull.host))
	details.branch = pull.branch or (if existing and existing.details then existing.details.branch else nil)

	local recorded = setRef(item, {
		source = if existing then existing.source else source,
		kind = "pull",
		type = "pr",
		key = getGithubKey(pull.owner, pull.name, `#{pull.number}`, pull.host),
		id = if pull.repoId then getGithubId(pull.repoId, `#{pull.number}`, pull.host) else nil,
		url = pull.url,
		status = if pull.state == "OPEN" and pull.draft then "draft" else pull.state:lower(),
		isDone = pull.state == "MERGED",
		updatedAt = pull.updatedAt,
		details = details,
	})

	setPullFacts(recorded, details)
end

return setPullRef
