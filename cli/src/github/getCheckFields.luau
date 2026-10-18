-- The fields that describe a pull request's checks on its latest commit, as `getCheckState`, `getCheckProgress`, and
-- `getCheckCounts` read them.
local CHECK_FIELDS =
	"commits(last: 1) { nodes { commit { statusCheckRollup { state contexts(first: 0) { checkRunCountsByState { state count } statusContextCountsByState { state count } } } } } }"

local function getCheckFields(): string
	return CHECK_FIELDS
end

return getCheckFields
