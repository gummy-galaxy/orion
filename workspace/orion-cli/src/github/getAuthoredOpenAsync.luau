local getListFields = require("@root/github/getListFields")
local getString = require("@root/github/getString")
local githubTypes = require("@root/github/types")
local isTimeout = require("@root/github/isTimeout")
local json = require("@std/json")
local parsePull = require("@root/github/parsePull")
local queryAsync = require("@root/github/queryAsync")
local types = require("@root/types")

type PullState = githubTypes.PullState
type CommandRunner = types.CommandRunner

local PAGE_SIZE = 100
local SMALLEST_PAGE = 25

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

--[[
	Lists the viewer's open pull requests with the light fields from
	`getListFields`, most recently updated first. A page that times out is
	retried at half the size, down to 25.
]]
local function getAuthoredOpenAsync(run: CommandRunner): ({ PullState }, string)
	local authored: { PullState } = {}
	local cursor: string? = nil
	local login: string? = nil
	local size = PAGE_SIZE

	while true do
		local after = if cursor then `, after: {json.serialize(cursor)}` else ""
		local succeeded, data = pcall(
			queryAsync,
			run,
			`query \{ viewer \{ login pullRequests(first: {size}, states: OPEN, orderBy: \{field: `
				.. `UPDATED_AT, direction: DESC}{after}) \{ nodes \{ {getListFields()} repository \{ name owner `
				.. `\{ login } } } pageInfo \{ hasNextPage endCursor } } } }`,
			nil
		)

		if not succeeded then
			if isTimeout(tostring(data)) and size > SMALLEST_PAGE then
				size = math.max(size // 2, SMALLEST_PAGE)
				continue
			end

			error(data, 0)
		end

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

return getAuthoredOpenAsync
