local json = require("@std/json")

local types = require("@root/types")

type Doc = types.Doc

export type FoundEntry = {
	-- The directory's key for the repository: its id, with the host in front on
	-- GitHub Enterprise.
	key: string,
	-- What the repository is called now, as owner/name.
	name: string,
}

--[[
	The repository the canvas's directory knows by `location`, an owner/name
	with the host in front on GitHub Enterprise, as `getKeyRepo` gives it. A
	current name wins over another repository's old name. Reads only what this
	machine has recorded, so it never waits on GitHub.
]]
local function findRepository(doc: Doc, location: string): FoundEntry?
	local repositories = doc.repositories

	if not repositories then
		return nil
	end

	local host, rest = location:lower():match("^([^/]+)/([^/]+/[^/]+)$")
	local prefix = if host then `{host}/` else ""
	local wanted = rest or location:lower()
	local byAlias: FoundEntry? = nil

	for key, value in repositories do
		local entry = json.asObject(value)
		local name = if entry and type(entry.name) == "string" then entry.name else nil

		if not entry or not name or (key:match("^(.*/)") or "") ~= prefix then
			continue
		end

		if name:lower() == wanted then
			return { key = key, name = name }
		end

		for _, alias in json.asArray(entry.aliases) or {} do
			if type(alias) == "string" and alias:lower() == wanted then
				byAlias = byAlias or { key = key, name = name }
			end
		end
	end

	return byAlias
end

return findRepository
