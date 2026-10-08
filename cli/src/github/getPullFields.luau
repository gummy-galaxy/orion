local PULL_FIELDS =
	"number title body url state baseRefName headRefName isDraft reviewDecision author { login } updatedAt additions deletions commits(last: 1) { nodes { commit { statusCheckRollup { state } } } } reviewRequests(first: 20) { totalCount nodes { requestedReviewer { ... on User { login } } } }"

local function getPullFields(): string
	return PULL_FIELDS
end

return getPullFields
