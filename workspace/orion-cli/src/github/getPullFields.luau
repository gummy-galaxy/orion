local getCheckFields = require("@root/github/getCheckFields")

local PULL_FIELDS = "number title body url state baseRefName headRefName isDraft mergeable mergeStateStatus headRefOid reviewDecision author { login } updatedAt additions deletions "
	.. getCheckFields()
	.. " reviewRequests(first: 20) { totalCount nodes { requestedReviewer { ... on User { login } } } }"

local function getPullFields(): string
	return PULL_FIELDS
end

return getPullFields
