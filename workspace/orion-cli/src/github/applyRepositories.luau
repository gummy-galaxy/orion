local getGithubId = require("@root/refs/getGithubId")
local getKeyRepo = require("@root/refs/getKeyRepo")
local getRefs = require("@root/refs/getRefs")
local githubTypes = require("@root/github/types")
local setRepository = require("@root/github/setRepository")
local types = require("@root/types")

type Doc = types.Doc
type FoundRepository = githubTypes.FoundRepository

local GITHUB_KINDS = { pull = true, issue = true, branch = true }

-- Gives each GitHub ref with no id the id of the repository
-- `fetchRepositoriesAsync` found for its key, and records each repository's
-- current name in the directory.
local function applyRepositories(doc: Doc, found: { FoundRepository }, checkedAt: string)
	local byLocation: { [string]: FoundRepository } = {}

	for _, repository in found do
		byLocation[repository.location] = repository
		local alias = repository.location:match("^[^/]+/([^/]+/[^/]+)$") or repository.location
		setRepository(doc, repository.host, repository.id, repository.name, checkedAt, alias)
	end

	if next(byLocation) == nil then
		return
	end

	for _, item in doc.nodes do
		for _, ref in getRefs(item) do
			local repo = if GITHUB_KINDS[ref.kind] and not ref.id then getKeyRepo(ref.key) else nil
			local repository = if repo then byLocation[repo.location:lower()] else nil

			if repo and repository then
				ref.id = getGithubId(repository.id, repo.suffix, repository.host)
			end
		end
	end
end

return applyRepositories
