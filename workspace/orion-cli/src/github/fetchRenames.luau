local json = require("@std/json")

local getKeyRepo = require("@root/refs/getKeyRepo")
local getRefs = require("@root/refs/getRefs")
local getString = require("@root/github/getString")
local query = require("@root/github/query")
local types = require("@root/types")

type Doc = types.Doc
type CommandRunner = types.CommandRunner
type KeyRepo = getKeyRepo.KeyRepo

local BATCH_SIZE = 25
local PUBLIC_HOST = "github.com"
local GITHUB_KINDS = { pull = true, issue = true, branch = true }

-- The repositories the canvas names, by host: those of its cards' GitHub refs, and those its CI snoozes cover.
local function getRepos(doc: Doc): { [string]: { [string]: KeyRepo } }
	local byHost: { [string]: { [string]: KeyRepo } } = {}

	local function add(repo: KeyRepo?)
		if repo then
			byHost[repo.host] = byHost[repo.host] or {}
			byHost[repo.host][repo.location:lower()] = repo
		end
	end

	for _, item in doc.nodes do
		for _, ref in getRefs(item) do
			if GITHUB_KINDS[ref.kind] then
				add(getKeyRepo(ref.key))
			end
		end
	end

	for _, snooze in doc.settings.checkSnoozes do
		add(getKeyRepo(`{snooze.repo}#0`))
	end

	return byHost
end

--[[
	Asks GitHub where each repository the canvas names lives now. GitHub follows a rename or transfer when asked for a
	repository by its old name, so one aliased query per 25 repositories finds every move. Returns the new owner/name by
	the old repository's lowercased location. A failed query finds no moves, so ingest goes on with the names it has.
]]
local function fetchRenames(doc: Doc, run: CommandRunner): { [string]: string }
	local renames: { [string]: string } = {}

	for host, repos in getRepos(doc) do
		local list: { KeyRepo } = {}

		for _, repo in repos do
			table.insert(list, repo)
		end

		for start = 1, #list, BATCH_SIZE do
			local batch = table.move(list, start, math.min(start + BATCH_SIZE - 1, #list), 1, {})
			local parts = {}

			for index, repo in batch do
				table.insert(
					parts,
					`r{index}: repository(owner: {json.serialize(repo.owner)}, name: {json.serialize(repo.name)}) \{ nameWithOwner }`
				)
			end

			local succeeded, data =
				pcall(query, run, `query \{ {table.concat(parts, " ")} }`, if host == PUBLIC_HOST then nil else host)

			if not succeeded or not data then
				continue
			end

			for index, repo in batch do
				local found = json.asObject(data[`r{index}`])
				local current = if found then getString(found.nameWithOwner) else nil

				if current and current:lower() ~= (`{repo.owner}/{repo.name}`):lower() then
					renames[repo.location:lower()] = current
				end
			end
		end
	end

	return renames
end

return fetchRenames
