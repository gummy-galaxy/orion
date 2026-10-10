local getKey = require("@root/github/getKey")
local getPullFields = require("@root/github/getPullFields")
local githubTypes = require("@root/github/types")
local json = require("@std/json")
local parsePull = require("@root/github/parsePull")
local query = require("@root/github/query")
local types = require("@root/types")

type Ref = githubTypes.Ref
type PullState = githubTypes.PullState
type CommandRunner = types.CommandRunner

local BATCH_SIZE = 25
local NAME_PATTERN = "^[%w%-%._]+$"

local function fetchPulls(run: CommandRunner, refs: { Ref }): { [string]: PullState }
	local found: { [string]: PullState } = {}
	local byHost: { [string]: { Ref } } = {}

	for _, ref in refs do
		local host = ref.host or "github.com"
		byHost[host] = byHost[host] or {}
		table.insert(byHost[host], ref)
	end

	for host, hostRefs in byHost do
		for start = 1, #hostRefs, BATCH_SIZE do
			local parts = {}
			local batch: { [string]: Ref } = {}

			for index = start, math.min(start + BATCH_SIZE - 1, #hostRefs) do
				local ref = hostRefs[index]
				assert(
					ref.owner:match(NAME_PATTERN) and ref.name:match(NAME_PATTERN),
					`invalid repository {ref.owner}/{ref.name}`
				)
				local alias = `p{index}`
				batch[alias] = ref
				table.insert(
					parts,
					`{alias}: repository(owner: "{ref.owner}", name: "{ref.name}") \{ pullRequest(number: {ref.number}) \{ {getPullFields()} } }`
				)
			end

			local data = query(run, `query \{ {table.concat(parts, " ")} }`, if host == "github.com" then nil else host)

			if data then
				for alias, ref in batch do
					local repository = json.asObject(data[alias])
					local pull = if repository then json.asObject(repository.pullRequest) else nil
					local parsed = if pull then parsePull(pull, ref.owner, ref.name, ref.host) else nil

					if parsed then
						found[getKey(ref)] = parsed
					end
				end
			end
		end
	end

	return found
end

return fetchPulls
