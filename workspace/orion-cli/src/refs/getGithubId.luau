-- A GitHub ref's id: GitHub's number for its repository, followed by #number or @branch, with the host in front on GitHub
-- Enterprise. A repository keeps its id when it's renamed or transferred, and pull requests and issues keep their
-- numbers, so the id survives a move.
local function getGithubId(repoId: string, suffix: string, host: string?): string
	local prefix = if host and host:lower() ~= "github.com" then `{host:lower()}/` else ""
	return `{prefix}{repoId}{suffix}`
end

return getGithubId
