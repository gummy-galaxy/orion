local PULL_FIELDS =
	"number title body url state baseRefName headRefName isDraft mergeable mergeStateStatus headRefOid reviewDecision author { login } updatedAt additions deletions commits(last: 1) { nodes { commit { statusCheckRollup { state contexts(first: 0) { checkRunCountsByState { state count } statusContextCountsByState { state count } } } } } } reviewRequests(first: 20) { totalCount nodes { requestedReviewer { ... on User { login } } } }"

local function getPullFields(): string
	return PULL_FIELDS
end

return getPullFields
