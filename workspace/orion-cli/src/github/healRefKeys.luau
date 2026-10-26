local json = require("@std/json")

local findRepository = require("@root/github/findRepository")
local getKeyRepo = require("@root/refs/getKeyRepo")
local getMovedUrl = require("@root/github/getMovedUrl")
local getRefs = require("@root/refs/getRefs")
local isSameRef = require("@root/refs/isSameRef")
local types = require("@root/types")

type Doc = types.Doc
type Ref = types.Ref

export type Move = { from: string, to: string }

local GITHUB_KINDS = { pull = true, issue = true, branch = true }

--[[
	Renames every GitHub ref whose repository the directory knows by a different
	name now, keeping its id, number or branch, and the rest of its URL. A
	card's repository follows its refs. A card left with two refs that are now
	the same keeps the first. Returns the moves that changed something, sorted
	by old name.
]]
local function healRefKeys(doc: Doc): { Move }
	local repositories = doc.repositories
	local applied: { [string]: Move } = {}

	if not repositories then
		return {}
	end

	for _, item in doc.nodes do
		local kept: { Ref } = {}
		local changed = false

		for _, ref in getRefs(item) do
			local entry = if GITHUB_KINDS[ref.kind] and ref.id
				then json.asObject(repositories[(ref.id :: string):match("^([^#@]+)") or ""])
				else nil
			local current = if entry and type(entry.name) == "string" then entry.name else nil
			local repo = if current then getKeyRepo(ref.key) else nil
			local previous = if repo then `{repo.owner}/{repo.name}` else nil

			if repo and current and previous and previous:lower() ~= current:lower() then
				local prefix = if repo.host == "github.com" then "" else `{repo.host}/`
				ref.key = `{prefix}{current}{repo.suffix}`
				ref.url = if ref.url then getMovedUrl(ref.url, previous, current) else nil
				applied[previous:lower()] = applied[previous:lower()] or { from = previous, to = current }

				if type(item.data.repo) == "string" and item.data.repo:lower() == previous:lower() then
					item.data.repo = current
				end
			end

			local isDuplicate = false

			for _, other in kept do
				isDuplicate = isDuplicate or isSameRef(other, ref)
			end

			if isDuplicate then
				changed = true
			else
				table.insert(kept, ref)
			end
		end

		if changed then
			item.data.refs = kept :: any
		end
	end

	local snoozes = doc.settings.checkSnoozes

	for index = #snoozes, 1, -1 do
		local snooze = snoozes[index]
		local found = findRepository(doc, snooze.repo)

		if found and found.name:lower() ~= snooze.repo:lower() then
			applied[snooze.repo:lower()] = applied[snooze.repo:lower()] or { from = snooze.repo, to = found.name }
			snooze.repo = found.name
		end
	end

	-- A snooze moved onto a name that already had one for the same job gives
	-- way to it.
	for index = #snoozes, 1, -1 do
		for earlier = 1, index - 1 do
			local snooze, other = snoozes[index], snoozes[earlier]

			if other.name == snooze.name and other.repo:lower() == snooze.repo:lower() then
				table.remove(snoozes, index)
				break
			end
		end
	end

	local moves: { Move } = {}

	for _, move in applied do
		table.insert(moves, move)
	end

	table.sort(moves, function(a: Move, b: Move): boolean
		return a.from:lower() < b.from:lower()
	end)

	return moves
end

return healRefKeys
