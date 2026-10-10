local function getGithubKey(owner: string, name: string, suffix: string, host: string?): string
	local prefix = if host and host ~= "github.com" then `{host}/` else ""
	return `{prefix}{owner}/{name}{suffix}`
end

return getGithubKey
