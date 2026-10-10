local getKey = require("@root/github/getKey")
local getPullFields = require("@root/github/getPullFields")
local getString = require("@root/github/getString")
local githubTypes = require("@root/github/types")
local isListed = require("@root/github/isListed")
local json = require("@std/json")
local parsePull = require("@root/github/parsePull")
local query = require("@root/github/query")
local types = require("@root/types")

type PullState = githubTypes.PullState
type IssueState = githubTypes.IssueState
type CommandRunner = types.CommandRunner

local function getSearchPage(
	run: CommandRunner,
	host: string,
	expression: string,
	cursor: string?
): (json.Array, string?, boolean)
	local after = if cursor then `, after: {json.serialize(cursor)}` else ""
	local source =
		`query \{ search(query: {json.serialize(expression)}, type: ISSUE, first: 100{after}) \{ nodes \{ ... on PullRequest \{ {getPullFields()} repository \{ name owner \{ login } } } ... on Issue \{ number title url repository \{ name owner \{ login } } } } pageInfo \{ hasNextPage endCursor } } }`
	local data = assert(query(run, source, host), `could not search {host}`)
	local search = assert(json.asObject(data.search), `invalid search response from {host}`)
	local info = json.asObject(search.pageInfo)
	return json.asArray(search.nodes) or {},
		if info then getString(info.endCursor) else nil,
		if info then info.hasNextPage == true else false
end

local function getInvolved(
	run: CommandRunner,
	host: string,
	owners: { string },
	since: string,
	include: { string }?,
	exclude: { string }?
): ({ PullState }, { IssueState }, string)
	local viewerData = assert(query(run, "query { viewer { login } }", host), `could not fetch GitHub viewer on {host}`)
	local viewer = json.asObject(viewerData.viewer)
	local login = assert(if viewer then getString(viewer.login) else nil, `could not fetch GitHub viewer on {host}`)
	local pulls: { PullState } = {}
	local issues: { IssueState } = {}
	local seen: { [string]: boolean } = {}

	for _, owner in owners do
		for _, filter in
			{
				"is:open is:pr involves:@me",
				`is:pr is:merged author:@me merged:>={since}`,
				"is:open is:issue assignee:@me",
			}
		do
			local cursor: string? = nil
			local count = 0

			while count < 300 do
				local nodes, nextCursor, more = getSearchPage(run, host, `{filter} user:{owner}`, cursor)

				for _, raw in nodes do
					count += 1
					local object = json.asObject(raw)
					local repository = if object then json.asObject(object.repository) else nil
					local repositoryOwner = if repository then json.asObject(repository.owner) else nil
					local name = if repository then getString(repository.name) else nil
					local actualOwner = if repositoryOwner then getString(repositoryOwner.login) else nil

					if not object or not name or not actualOwner or actualOwner:lower() ~= owner:lower() then
						continue
					end

					if include and not isListed(include, name) or isListed(exclude, name) then
						continue
					end

					local number = object.number

					if type(number) ~= "number" then
						continue
					end

					local key = getKey({ host = host, owner = actualOwner, name = name, number = number })

					if seen[key] then
						continue
					end

					local pull = parsePull(object, actualOwner, name, host)

					if pull then
						seen[key] = true
						table.insert(pulls, pull)
					elseif type(object.title) == "string" and type(object.url) == "string" then
						seen[key] = true
						table.insert(issues, {
							owner = actualOwner,
							name = name,
							number = number,
							title = object.title,
							url = object.url,
							host = host,
						})
					end
				end

				if not more or not nextCursor or #nodes == 0 then
					break
				end

				cursor = nextCursor
			end
		end
	end

	return pulls, issues, login
end

return getInvolved
