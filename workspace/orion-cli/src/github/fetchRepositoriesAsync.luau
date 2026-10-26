local json = require("@std/json")

local getKeyRepo = require("@root/refs/getKeyRepo")
local getRefs = require("@root/refs/getRefs")
local getRepoId = require("@root/github/getRepoId")
local getString = require("@root/github/getString")
local githubTypes = require("@root/github/types")
local queryAsync = require("@root/github/queryAsync")
local types = require("@root/types")

type Doc = types.Doc
type CommandRunner = types.CommandRunner
type KeyRepo = getKeyRepo.KeyRepo
type FoundRepository = githubTypes.FoundRepository

local BATCH_SIZE = 25
local PUBLIC_HOST = "github.com"
local GITHUB_KINDS = { pull = true, issue = true, branch = true }

-- The repositories named by the canvas's GitHub refs that have no id yet, by host.
local function getUnresolved(doc: Doc): { [string]: { [string]: KeyRepo } }
	local byHost: { [string]: { [string]: KeyRepo } } = {}

	for _, item in doc.nodes do
		for _, ref in getRefs(item) do
			local repo = if GITHUB_KINDS[ref.kind] and not ref.id then getKeyRepo(ref.key) else nil

			if repo then
				byHost[repo.host] = byHost[repo.host] or {}
				byHost[repo.host][repo.location:lower()] = repo
			end
		end
	end

	return byHost
end

--[[
	Asks GitHub for the id and current name of each repository the canvas's GitHub refs name without an id, in one
	aliased query per 25 repositories. GitHub answers a repository's old name after a rename or transfer, so refs from
	before a move still resolve. It reads `doc` without changing it. A repository GitHub doesn't find, or a failed
	query, is left out, and its refs try again next time.
]]
local function fetchRepositoriesAsync(doc: Doc, run: CommandRunner): { FoundRepository }
	local found: { FoundRepository } = {}

	for host, repos in getUnresolved(doc) do
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
					`r{index}: repository(owner: {json.serialize(repo.owner)}, name: {json.serialize(repo.name)}) \{ databaseId nameWithOwner }`
				)
			end

			local succeeded, data = pcall(
				queryAsync,
				run,
				`query \{ {table.concat(parts, " ")} }`,
				if host == PUBLIC_HOST then nil else host
			)

			if not succeeded or not data then
				continue
			end

			for index, repo in batch do
				local object = json.asObject(data[`r{index}`])
				local id = getRepoId(object)
				local name = if object then getString(object.nameWithOwner) else nil

				if id and name then
					table.insert(found, { location = repo.location:lower(), host = host, id = id, name = name })
				end
			end
		end
	end

	return found
end

return fetchRepositoriesAsync
