local findRepository = require("@root/github/findRepository")
local getKeyRepo = require("@root/refs/getKeyRepo")
local types = require("@root/types")

type Doc = types.Doc

-- A GitHub key under its repository's current name, when the canvas's directory knows the name it uses, current or old.
-- Any other key comes back as it is.
local function getCurrentKey(doc: Doc, key: string): string
	local repo = getKeyRepo(key)
	local found = if repo then findRepository(doc, repo.location) else nil

	if not repo or not found then
		return key
	end

	local prefix = if repo.host == "github.com" then "" else `{repo.host}/`
	return `{prefix}{found.name}{repo.suffix}`
end

return getCurrentKey
