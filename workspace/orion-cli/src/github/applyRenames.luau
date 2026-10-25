local json = require("@std/json")

local getKeyRepo = require("@root/refs/getKeyRepo")
local types = require("@root/types")

type Doc = types.Doc

export type Rename = { from: string, to: string }

local GITHUB_KINDS = { pull = true, issue = true, branch = true }

-- Points a ref's URL at the moved repository, when its path starts with the old owner/name.
local function getMovedUrl(url: string, previous: string, current: string): string
	local origin, path = url:match("^(https?://[^/]+/)([^/]+/[^/#?]+)")

	if not origin or not path or path:lower() ~= previous:lower() then
		return url
	end

	return `{origin}{current}{url:sub(#origin + #path + 1)}`
end

--[[
	Moves every GitHub ref, card repository, and CI snooze that names a renamed or transferred repository to its new
	name, so ingest matches what GitHub now returns to the cards that already track it. `renames` comes from
	`fetchRenames`. A card that already has the ref under its new name drops the old one, as does a snooze. Returns the
	moves that changed something, sorted by old name.
]]
local function applyRenames(doc: Doc, renames: { [string]: string }): { Rename }
	local applied: { [string]: Rename } = {}

	if next(renames) == nil then
		return {}
	end

	local function move(location: string): string?
		local current = renames[location:lower()]

		if current then
			applied[location:lower()] = applied[location:lower()] or { from = location, to = current }
		end

		return current
	end

	for _, item in doc.nodes do
		local refs = json.asArray(item.data.refs)

		for index = #(refs or {}), 1, -1 do
			local ref = json.asObject((refs :: json.Array)[index])
			local key = if ref then ref.key else nil
			local repo = if type(key) == "string" and GITHUB_KINDS[(ref :: json.Object).kind]
				then getKeyRepo(key)
				else nil
			local current = if repo then move(repo.location) else nil

			if not ref or not repo or not current then
				continue
			end

			local prefix = if repo.host == "github.com" then "" else `{repo.host}/`
			local movedKey = `{prefix}{current}{repo.suffix}`
			local isDuplicate = false

			for _, other in refs :: json.Array do
				local otherRef = json.asObject(other)

				if
					otherRef
					and otherRef ~= ref
					and otherRef.kind == ref.kind
					and type(otherRef.key) == "string"
					and otherRef.key:lower() == movedKey:lower()
				then
					isDuplicate = true
				end
			end

			if isDuplicate then
				table.remove(refs :: json.Array, index)
				continue
			end

			ref.key = movedKey

			if type(ref.url) == "string" then
				ref.url = getMovedUrl(ref.url, `{repo.owner}/{repo.name}`, current)
			end

			if type(item.data.repo) == "string" and item.data.repo:lower() == (`{repo.owner}/{repo.name}`):lower() then
				item.data.repo = current
			end
		end

		-- A card with no GitHub ref can still name its repository.
		local repo = item.data.repo
		local current = if type(repo) == "string" then move(repo) else nil

		if current then
			item.data.repo = current
		end
	end

	local snoozes = doc.settings.checkSnoozes

	for index = #snoozes, 1, -1 do
		local snooze = snoozes[index]
		local current = move(snooze.repo)

		if not current then
			continue
		end

		local isDuplicate = false

		for _, other in snoozes do
			if other ~= snooze and other.name == snooze.name and other.repo:lower() == current:lower() then
				isDuplicate = true
			end
		end

		if isDuplicate then
			table.remove(snoozes, index)
		else
			snooze.repo = current
		end
	end

	local moves: { Rename } = {}

	for _, rename in applied do
		table.insert(moves, rename)
	end

	table.sort(moves, function(a: Rename, b: Rename): boolean
		return a.from:lower() < b.from:lower()
	end)

	return moves
end

return applyRenames
