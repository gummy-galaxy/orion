local getPullFields = require("@root/github/getPullFields")
local getString = require("@root/github/getString")
local githubTypes = require("@root/github/types")
local json = require("@std/json")
local parsePull = require("@root/github/parsePull")
local query = require("@root/github/query")
local types = require("@root/types")

type PullState = githubTypes.PullState
type CommandRunner = types.CommandRunner

local function getPullList(nodes: json.Array?): { PullState }
	local pulls: { PullState } = {}

	for _, raw in nodes or {} do
		local object = json.asObject(raw)
		local repository = if object then json.asObject(object.repository) else nil
		local owner = if repository then json.asObject(repository.owner) else nil
		local name = if repository then getString(repository.name) else nil
		local login = if owner then getString(owner.login) else nil

		if object and name and login then
			local parsed = parsePull(object, login, name)

			if parsed then
				table.insert(pulls, parsed)
			end
		end
	end

	return pulls
end

local function getAuthoredOpen(run: CommandRunner): ({ PullState }, string)
	local authored: { PullState } = {}
	local cursor: string? = nil
	local login: string? = nil
	while true do
		local after = if cursor then `, after: {json.serialize(cursor)}` else ""
		local data = query(
			run,
			`query \{ viewer \{ login pullRequests(first: 100, states: OPEN, orderBy: \{field: UPDATED_AT, direction: DESC}{after}) \{ nodes \{ {getPullFields()} repository \{ name owner \{ login } } } pageInfo \{ hasNextPage endCursor } } } }`
		)
		local viewer = if data then json.asObject(data.viewer) else nil
		assert(viewer and type(viewer.login) == "string", "could not fetch GitHub viewer")
		login = viewer.login :: string
		local pulls = json.asObject(viewer.pullRequests)
		for _, pull in getPullList(if pulls then json.asArray(pulls.nodes) else nil) do
			table.insert(authored, pull)
		end
		local pageInfo = if pulls then json.asObject(pulls.pageInfo) else nil
		if not pageInfo or pageInfo.hasNextPage ~= true then
			break
		end
		local nextCursor = getString(pageInfo.endCursor)
		assert(nextCursor and nextCursor ~= cursor, "invalid GitHub pull request cursor")
		cursor = nextCursor
	end
	return authored, login :: string
end

return getAuthoredOpen
