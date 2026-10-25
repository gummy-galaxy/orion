export type KeyRepo = {
	-- The key's repository, as renames are keyed: owner/name, with the host in front on GitHub Enterprise.
	location: string,
	host: string,
	owner: string,
	name: string,
	-- What follows the repository: #number for pull requests and issues, @branch for branches.
	suffix: string,
}

local PUBLIC_HOST = "github.com"

-- Splits a GitHub ref key into its repository and the rest. The first # or @ ends the repository, because names never
-- contain either.
local function getKeyRepo(key: string): KeyRepo?
	local location, suffix = key:match("^([^#@]+)([#@].*)$")

	if not location then
		return nil
	end

	local host, owner, name = location:match("^([^/]+)/([^/]+)/([^/]+)$")

	if not host then
		owner, name = location:match("^([^/]+)/([^/]+)$")
	end

	if not owner or not name then
		return nil
	end

	local lowerHost = (host or PUBLIC_HOST):lower()

	return {
		location = if lowerHost == PUBLIC_HOST then `{owner}/{name}` else `{lowerHost}/{owner}/{name}`,
		host = lowerHost,
		owner = owner,
		name = assert(name),
		suffix = assert(suffix),
	}
end

return getKeyRepo
