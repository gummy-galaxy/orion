local json = require("@std/json")

local types = require("@root/types")

type Doc = types.Doc

local function getAliases(entry: json.Object?): { string }
	local aliases: { string } = {}

	for _, alias in (if entry then json.asArray(entry.aliases) else nil) or {} do
		if type(alias) == "string" then
			table.insert(aliases, alias)
		end
	end

	return aliases
end

local function hasName(names: { string }, name: string): boolean
	for _, other in names do
		if other:lower() == name:lower() then
			return true
		end
	end

	return false
end

--[[
	Records what GitHub said a repository is called now in the canvas's directory, by its id, with the host in front on
	GitHub Enterprise as in ref ids. A name it had before stays as an alias, as does `alias`, a name GitHub answered for
	it, so either still finds it. A name GitHub gives this repository stops being another repository's alias, since a
	freed name can be taken by a new one.
]]
local function setRepository(doc: Doc, host: string?, id: string, name: string, checkedAt: string, alias: string?)
	local prefix = if host and host:lower() ~= "github.com" then `{host:lower()}/` else ""
	local key = `{prefix}{id}`
	local repositories = doc.repositories or json.object({})
	local previous = json.asObject(repositories[key])
	local aliases = getAliases(previous)
	local former = if previous and type(previous.name) == "string" then previous.name else nil

	for _, candidate in { former, alias } do
		if candidate and candidate:lower() ~= name:lower() and not hasName(aliases, candidate) then
			table.insert(aliases, candidate)
		end
	end

	local taken = { name, alias or name }

	for otherKey, value in repositories do
		local other = json.asObject(value)

		if otherKey ~= key and other and (otherKey:match("^(.*/)") or "") == prefix then
			local kept: json.Array = {}

			for _, otherAlias in getAliases(other) do
				if not hasName(taken, otherAlias) then
					table.insert(kept, otherAlias)
				end
			end

			other.aliases = if #kept > 0 then kept else nil
		end
	end

	local entry = json.object({ name = name, checkedAt = checkedAt })
	entry.aliases = if #aliases > 0 then aliases :: json.Array else nil
	repositories[key] = entry
	doc.repositories = repositories
end

return setRepository
