local json = require("@std/json")

-- GitHub's number for a repository, from a `repository { databaseId }` selection, as a string. The number never changes,
-- where GitHub's node ids for the same repository come in more than one format.
local function getRepoId(repository: json.Object?): string?
	local id = if repository then repository.databaseId else nil
	return if type(id) == "number" then string.format("%d", id) else nil
end

return getRepoId
