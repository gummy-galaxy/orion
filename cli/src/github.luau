local json = require("@std/json")

local graph = require("@root/graph")
local match = require("@root/match")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type CommandRunner = types.CommandRunner

export type PullState = {
	owner: string,
	name: string,
	number: number,
	state: string,
	baseRefName: string,
	headRefName: string,
	draft: boolean,
	reviewDecision: string?,
	reviewRequests: number,
	requestedReviewers: { string },
	title: string,
	url: string,
	author: string,
	updatedAt: string,
	additions: number,
	deletions: number,
	checks: string?,
	branch: string?,
	body: string?,
	host: string?,
}

export type Ref = { owner: string, name: string, number: number, host: string? }
export type Change = {
	id: string,
	label: string,
	fromStatus: string,
	toStatus: string,
	fromWho: string?,
	toWho: string?,
	closed: boolean,
}
export type StackLink = { from: string, to: string }
export type Report = {
	changes: { Change },
	missing: { string },
	added: { string },
	linked: { StackLink },
	unlinked: { StackLink },
	checked: number,
}
export type Fetched = {
	pulls: { [string]: PullState },
	authored: { PullState },
	viewer: string,
	discover: boolean,
}

local BATCH_SIZE = 25
local PULL_FIELDS =
	"number title body url state baseRefName headRefName isDraft reviewDecision author { login } updatedAt additions deletions commits(last: 1) { nodes { commit { statusCheckRollup { state } } } } reviewRequests(first: 20) { totalCount nodes { requestedReviewer { ... on User { login } } } }"
local NAME_PATTERN = "^[%w%-%._]+$"
local INBOX_ID = "inbox"
local github = {}

function github.getKey(ref: Ref): string
	local host = if ref.host and ref.host ~= "github.com" then `{ref.host}/` else ""
	return string.lower(`{host}{ref.owner}/{ref.name}#{ref.number}`)
end

function github.getRefFor(item: Item, defaultOwner: string): Ref?
	local repo = item.data.repo
	local number = item.data.pr

	if type(repo) ~= "string" or type(number) ~= "number" then
		return nil
	end

	local owner, name = repo:match("^([^/]+)/([^/]+)$")
	return {
		owner = owner or defaultOwner,
		name = name or repo,
		number = number,
		host = if type(item.data.host) == "string" then item.data.host else nil,
	}
end

local function getString(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

local function getPullFromObject(object: json.Object, owner: string, name: string, host: string?): PullState?
	local number, state, url = object.number, object.state, object.url

	if type(number) ~= "number" or type(state) ~= "string" or type(url) ~= "string" then
		return nil
	end

	local requests = json.asObject(object.reviewRequests)
	local requestedReviewers: { string } = {}

	for _, raw in (if requests then json.asArray(requests.nodes) else nil) or {} do
		local node = json.asObject(raw)
		local reviewer = if node then json.asObject(node.requestedReviewer) else nil
		local login = if reviewer then getString(reviewer.login) else nil

		if login then
			table.insert(requestedReviewers, login)
		end
	end

	local author = json.asObject(object.author)
	local commits = json.asObject(object.commits)
	local commitNodes = if commits then json.asArray(commits.nodes) else nil
	local last = if commitNodes then json.asObject(commitNodes[1]) else nil
	local commit = if last then json.asObject(last.commit) else nil
	local rollup = if commit then json.asObject(commit.statusCheckRollup) else nil
	return {
		owner = owner,
		name = name,
		number = number,
		state = state,
		baseRefName = getString(object.baseRefName) or "",
		headRefName = getString(object.headRefName) or "",
		draft = object.isDraft == true,
		reviewDecision = getString(object.reviewDecision),
		reviewRequests = if requests and type(requests.totalCount) == "number" then requests.totalCount else 0,
		requestedReviewers = requestedReviewers,
		title = getString(object.title) or "",
		url = url,
		author = if author then getString(author.login) or "" else "",
		updatedAt = getString(object.updatedAt) or "",
		additions = if type(object.additions) == "number" then object.additions else 0,
		deletions = if type(object.deletions) == "number" then object.deletions else 0,
		checks = if rollup then getString(rollup.state) else nil,
		branch = getString(object.headRefName),
		body = getString(object.body),
		host = host,
	}
end

-- gh can exit non-zero for a partially resolved GraphQL query while retaining usable data.
function github.query(run: CommandRunner, source: string, host: string?): json.Object?
	local argv = { "gh", "api" }

	if host then
		table.insert(argv, "--hostname")
		table.insert(argv, host)
	end

	table.insert(argv, "graphql")
	table.insert(argv, "-f")
	table.insert(argv, `query={source}`)
	local ok, response = pcall(run, argv, nil)

	if not ok then
		return nil
	end

	local decodedOk, decoded = pcall(json.deserialize, response.stdout)
	local body = if decodedOk then json.asObject(decoded :: json.Value) else nil

	if body == nil then
		assert(response.ok, `gh api graphql failed: {response.stderr}`)
		return nil
	end

	return json.asObject(body.data)
end

local query = github.query

function github.fetchPulls(run: CommandRunner, refs: { Ref }): { [string]: PullState }
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
					`{alias}: repository(owner: "{ref.owner}", name: "{ref.name}") \{ pullRequest(number: {ref.number}) \{ {PULL_FIELDS} } }`
				)
			end

			local data = query(run, `query \{ {table.concat(parts, " ")} }`, if host == "github.com" then nil else host)

			if data then
				for alias, ref in batch do
					local repository = json.asObject(data[alias])
					local pull = if repository then json.asObject(repository.pullRequest) else nil
					local parsed = if pull then getPullFromObject(pull, ref.owner, ref.name, ref.host) else nil

					if parsed then
						found[github.getKey(ref)] = parsed
					end
				end
			end
		end
	end

	return found
end

local function getPullList(nodes: json.Array?): { PullState }
	local out: { PullState } = {}

	for _, raw in nodes or {} do
		local object = json.asObject(raw)
		local repository = if object then json.asObject(object.repository) else nil
		local owner = if repository then json.asObject(repository.owner) else nil
		local name = if repository then getString(repository.name) else nil
		local login = if owner then getString(owner.login) else nil

		if object and name and login then
			local parsed = getPullFromObject(object, login, name)

			if parsed then
				table.insert(out, parsed)
			end
		end
	end

	return out
end

export type IssueState = { owner: string, name: string, number: number, title: string, url: string, host: string? }

local function getSearchPage(
	run: CommandRunner,
	host: string,
	expression: string,
	cursor: string?
): (json.Array, string?, boolean)
	local after = if cursor then `, after: {json.serialize(cursor)}` else ""
	local source =
		`query \{ search(query: {json.serialize(expression)}, type: ISSUE, first: 100{after}) \{ nodes \{ ... on PullRequest \{ {PULL_FIELDS} repository \{ name owner \{ login } } } ... on Issue \{ number title url repository \{ name owner \{ login } } } } pageInfo \{ hasNextPage endCursor } } }`
	local data = assert(query(run, source, host), `could not search {host}`)
	local search = assert(json.asObject(data.search), `invalid search response from {host}`)
	local info = json.asObject(search.pageInfo)
	return json.asArray(search.nodes) or {},
		if info then getString(info.endCursor) else nil,
		if info then info.hasNextPage == true else false
end

local function isListed(repos: { string }?, name: string): boolean
	if not repos then
		return false
	end

	for _, repo in repos do
		if repo:lower() == name:lower() then
			return true
		end
	end

	return false
end

function github.getInvolved(
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

					local key = github.getKey({ host = host, owner = actualOwner, name = name, number = number })

					if seen[key] then
						continue
					end

					local pull = getPullFromObject(object, actualOwner, name, host)

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

function github.getAuthoredOpen(run: CommandRunner): ({ PullState }, string)
	local authored: { PullState } = {}
	local cursor: string? = nil
	local login: string? = nil
	while true do
		local after = if cursor then `, after: {json.serialize(cursor)}` else ""
		local data = query(
			run,
			`query \{ viewer \{ login pullRequests(first: 100, states: OPEN, orderBy: \{field: UPDATED_AT, direction: DESC}{after}) \{ nodes \{ {PULL_FIELDS} repository \{ name owner \{ login } } } pageInfo \{ hasNextPage endCursor } } } }`
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

local function isRequestedFrom(pull: PullState, viewer: string): boolean
	for _, login in pull.requestedReviewers do
		if login:lower() == viewer:lower() then
			return true
		end
	end

	return false
end

function github.getDesired(pull: PullState, status: string, who: string?, viewer: string): (string, string?)
	if pull.state == "MERGED" then
		return "done", nil
	elseif pull.state == "CLOSED" then
		return if status == "done" then "done" else "deferred", nil
	elseif status == "blocked" or status == "deferred" then
		return status, who
	elseif pull.author:lower() ~= viewer:lower() then
		return "review", if isRequestedFrom(pull, viewer) then "you" else nil
	elseif pull.draft or pull.reviewDecision == "CHANGES_REQUESTED" then
		return "active", "you"
	elseif pull.reviewDecision == "APPROVED" then
		return "review", "you"
	elseif pull.reviewRequests > 0 then
		return "review", "review"
	end

	return "review", "you"
end

function github.collect(doc: Doc, run: CommandRunner, discover: boolean): Fetched
	local refs: { Ref } = {}

	for _, item in doc.nodes do
		local ref = github.getRefFor(item, doc.settings.githubOwner)

		if ref then
			table.insert(refs, ref)
		end
	end

	local authored, viewer = github.getAuthoredOpen(run)
	return {
		pulls = github.fetchPulls(run, refs),
		authored = authored,
		viewer = viewer,
		discover = discover,
	}
end

function github.getRecorded(pull: PullState, viewer: string, checkedAt: string): json.Object
	local result = json.object({
		state = pull.state,
		draft = pull.draft,
		title = pull.title,
		url = pull.url,
		author = pull.author,
		mine = pull.author:lower() == viewer:lower(),
		requestedFromYou = isRequestedFrom(pull, viewer),
		updatedAt = pull.updatedAt,
		additions = pull.additions,
		deletions = pull.deletions,
		checkedAt = checkedAt,
	})
	result.reviewDecision = pull.reviewDecision
	result.checks = pull.checks
	return result
end

local recorded = github.getRecorded

local function getRepoName(doc: Doc, pull: PullState): string
	return if pull.owner:lower() == doc.settings.githubOwner:lower() then pull.name else `{pull.owner}/{pull.name}`
end

local function ensureGroup(doc: Doc, id: string, label: string, blurb: string)
	if not graph.find(doc, id) then
		table.insert(doc.nodes, {
			id = id,
			type = "cluster",
			position = graph.nextSlot(doc, nil),
			data = json.object({ kind = "cluster", label = label, blurb = blurb }),
		})
	end
end

local function isStacked(parent: PullState, child: PullState): boolean
	return parent.owner:lower() == child.owner:lower()
		and parent.name:lower() == child.name:lower()
		and parent.number ~= child.number
		and parent.headRefName ~= ""
		and parent.headRefName == child.baseRefName
end

local function syncStackLinks(doc: Doc, fetched: Fetched, report: Report)
	local pulls = table.clone(fetched.pulls)
	for _, pull in fetched.authored do
		local key = github.getKey(pull)
		if not pulls[key] then
			pulls[key] = pull
		end
	end

	local cards: { { id: string, pull: PullState } } = {}
	local byId: { [string]: PullState } = {}

	for _, item in doc.nodes do
		local ref = github.getRefFor(item, doc.settings.githubOwner)
		local pull = if ref then pulls[github.getKey(ref)] else nil

		if pull then
			table.insert(cards, { id = item.id, pull = pull })
			byId[item.id] = pull
		end
	end

	for index = #doc.links, 1, -1 do
		local link = doc.links[index]

		if link.origin ~= "stack" then
			continue
		end

		local parent, child = byId[link.from], byId[link.to]

		if parent and child and parent.state == "OPEN" and child.state == "OPEN" and not isStacked(parent, child) then
			table.remove(doc.links, index)
			table.insert(report.unlinked, { from = link.from, to = link.to })
		end
	end

	for _, parent in cards do
		for _, child in cards do
			if not isStacked(parent.pull, child.pull) then
				continue
			end

			local isLinked = false

			for _, link in doc.links do
				if
					(link.from == parent.id and link.to == child.id) or (link.from == child.id and link.to == parent.id)
				then
					isLinked = true
					break
				end
			end

			if not isLinked then
				graph.link(doc, parent.id, child.id, "blocks").origin = "stack"
				table.insert(report.linked, { from = parent.id, to = child.id })
			end
		end
	end
end

-- Your own open pull requests only belong on a canvas whose GitHub sources cover their repository.
-- A canvas without GitHub sources takes them all.
local function isInSources(doc: Doc, pull: PullState): boolean
	local hasSources = false
	for _, source in doc.settings.sources do
		if source.kind ~= "github" or (source.host or "github.com") ~= "github.com" then
			continue
		end
		hasSources = true
		if
			isListed(source.owners, pull.owner)
			and (not source.include or isListed(source.include, pull.name))
			and not isListed(source.exclude, pull.name)
		then
			return true
		end
	end
	return not hasSources
end

function github.apply(doc: Doc, fetched: Fetched, checkedAt: string): Report
	local report: Report = { changes = {}, missing = {}, added = {}, linked = {}, unlinked = {}, checked = 0 }
	local onCanvas: { [string]: boolean } = {}

	for _, item in doc.nodes do
		local ref = github.getRefFor(item, doc.settings.githubOwner)

		if not ref then
			continue
		end

		local key = github.getKey(ref)
		onCanvas[key] = true
		local pull = fetched.pulls[key]

		if not pull then
			table.insert(report.missing, item.id)
			continue
		end

		report.checked += 1
		local status, who = getString(item.data.status) or "todo", getString(item.data.who)
		local nextStatus, nextWho = github.getDesired(pull, status, who, fetched.viewer)

		if nextStatus ~= status or nextWho ~= who then
			table.insert(report.changes, {
				id = item.id,
				label = graph.label(item),
				fromStatus = status,
				toStatus = nextStatus,
				fromWho = who,
				toWho = nextWho,
				closed = pull.state == "CLOSED",
			})
			item.data.status, item.data.who = nextStatus, nextWho
		end

		item.data.github = recorded(pull, fetched.viewer, checkedAt)
		item.data.branch = pull.branch or item.data.branch
	end

	local unplaced: json.Array = {}

	for _, pull in fetched.authored do
		local key = github.getKey(pull)
		if onCanvas[key] or not isInSources(doc, pull) then
			continue
		end

		local repo = getRepoName(doc, pull)

		if fetched.discover then
			ensureGroup(doc, INBOX_ID, "Inbox", "Open pull requests found on GitHub that aren't placed yet.")
			local status, who = github.getDesired(pull, "todo", nil, fetched.viewer)
			local item = graph.addItem(doc, pull.title, {
				group = INBOX_ID,
				repo = repo,
				pr = pull.number,
				status = status,
				who = who,
			})
			item.data.github = recorded(pull, fetched.viewer, checkedAt)
			item.data.branch = pull.branch
			onCanvas[key] = true
			table.insert(report.added, item.id)
		else
			local candidates: json.Array = {}

			for _, candidate in match.candidates(doc, pull.title, pull.owner, pull.name) do
				table.insert(candidates, json.object({ id = candidate.id, score = candidate.score }))
			end

			table.insert(
				unplaced,
				json.object({
					repo = repo,
					number = pull.number,
					title = pull.title,
					url = pull.url,
					draft = pull.draft,
					updatedAt = pull.updatedAt,
					additions = pull.additions,
					deletions = pull.deletions,
					matches = candidates,
				})
			)
		end
	end

	syncStackLinks(doc, fetched, report)
	table.sort(unplaced, function(a, b)
		local left, right = json.asObject(a), json.asObject(b)
		local leftTime: string = if left then getString(left.updatedAt) or "" else ""
		local rightTime: string = if right then getString(right.updatedAt) or "" else ""
		return (tonumber((leftTime:gsub("%D", ""))) or 0) > (tonumber((rightTime:gsub("%D", ""))) or 0)
	end)

	doc.github = json.object({ viewer = fetched.viewer, checkedAt = checkedAt, unplaced = unplaced })
	return report
end

return table.freeze(github)
