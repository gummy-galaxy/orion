-- The fields a list of pull requests needs for branch matching, stack links,
-- and the unplaced list. The merge state, checks, and reviews in
-- `getPullFields` cost most of a query's time, so only pull requests that
-- become cards fetch them.
local LIST_FIELDS = "number title url state isDraft baseRefName headRefName updatedAt additions deletions repository { "
	.. "databaseId nameWithOwner }"

local function getListFields(): string
	return LIST_FIELDS
end

return getListFields
