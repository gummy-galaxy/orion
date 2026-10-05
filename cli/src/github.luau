local json = require("@std/json")

local graph = require("@root/graph")
local match = require("@root/match")
local refs = require("@root/refs")
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
	--- CLEAN, BLOCKED, DIRTY, and the rest of GitHub's MergeStateStatus.
	mergeState: string?,
	--- Whoever's latest review approves, sorted.
	approvers: { string },
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
	reviewAdded: { string },
	linked: { StackLink },
	unlinked: { StackLink },
	checked: number,
}
export type ReleaseRef = { owner: string, name: string, tag: string, host: string? }
export type ReleaseState = { name: string?, url: string, publishedAt: string?, draft: boolean, prerelease: boolean }
export type Fetched = {
	pulls: { [string]: PullState },
	--- Keyed by `github.releaseKey`. A tag with no release yet is absent.
	releases: { [string]: ReleaseState }?,
	authored: { PullState },
	reviews: { PullState },
	viewer: string,
	discover: boolean,
}

local BATCH_SIZE = 25
local PULL_FIELDS =
	"number title body url state baseRefName headRefName isDraft reviewDecision mergeStateStatus latestReviews(first: 20) { nodes { state author { login } } } author { login } updatedAt additions deletions commits(last: 1) { nodes { commit { statusCheckRollup { state } } } } reviewRequests(first: 20) { totalCount nodes { requestedReviewer { ... on User { login } } } }"
local NAME_PATTERN = "^[%w%-%._]+$"
local INBOX_ID = "inbox"
local REVIEWS_ID = "reviews"
local github = {}

function github.key(ref: Ref): string
	local host = if ref.host and ref.host ~= "github.com" then `{ref.host}/` else ""
	return string.lower(`{host}{ref.owner}/{ref.name}#{ref.number}`)
end

local function str(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

function github.keyOf(source: refs.Ref, defaultOwner: string): Ref?
	local repo = source.repo
	local number = source.number
	if type(repo) ~= "string" or type(number) ~= "number" then
		return nil
	end
	local owner, name = repo:match("^([^/]+)/([^/]+)$")
	return { owner = owner or defaultOwner, name = name or repo, number = number, host = str(source.host) }
end

--- The pull request a card shows, if it has one.
function github.refFor(item: Item, defaultOwner: string): Ref?
	local driver = refs.driver(item)
	return if driver then github.keyOf(driver, defaultOwner) else nil
end

export type PullSource = { key: Ref, source: refs.Ref }

function github.pullSources(item: Item, defaultOwner: string): { PullSource }
	local out: { PullSource } = {}
	if item.type ~= "task" then
		return out
	end
	for _, source in refs.pulls(item) do
		local key = github.keyOf(source, defaultOwner)
		if key then
			table.insert(out, { key = key, source = source })
		end
	end
	return out
end

local function pullFromObject(object: json.Object, owner: string, name: string, host: string?): PullState?
	local number, state, url = object.number, object.state, object.url
	if type(number) ~= "number" or type(state) ~= "string" or type(url) ~= "string" then
		return nil
	end
	local requests = json.asObject(object.reviewRequests)
	local requestedReviewers: { string } = {}
	for _, raw in (if requests then json.asArray(requests.nodes) else nil) or {} do
		local node = json.asObject(raw)
		local reviewer = if node then json.asObject(node.requestedReviewer) else nil
		local login = if reviewer then str(reviewer.login) else nil
		if login then
			table.insert(requestedReviewers, login)
		end
	end
	local approvers: { string } = {}
	local reviews = json.asObject(object.latestReviews)
	for _, raw in (if reviews then json.asArray(reviews.nodes) else nil) or {} do
		local review = json.asObject(raw)
		local reviewer = if review then json.asObject(review.author) else nil
		local login = if reviewer then str(reviewer.login) else nil
		if review and review.state == "APPROVED" and login then
			table.insert(approvers, login)
		end
	end
	table.sort(approvers)
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
		baseRefName = str(object.baseRefName) or "",
		headRefName = str(object.headRefName) or "",
		draft = object.isDraft == true,
		reviewDecision = str(object.reviewDecision),
		mergeState = str(object.mergeStateStatus),
		approvers = approvers,
		reviewRequests = if requests and type(requests.totalCount) == "number" then requests.totalCount else 0,
		requestedReviewers = requestedReviewers,
		title = str(object.title) or "",
		url = url,
		author = if author then str(author.login) or "" else "",
		updatedAt = str(object.updatedAt) or "",
		additions = if type(object.additions) == "number" then object.additions else 0,
		deletions = if type(object.deletions) == "number" then object.deletions else 0,
		checks = if rollup then str(rollup.state) else nil,
		branch = str(object.headRefName),
		body = str(object.body),
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

function github.fetch(run: CommandRunner, refs: { Ref }): { [string]: PullState }
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
					local parsed = if pull then pullFromObject(pull, ref.owner, ref.name, ref.host) else nil
					if parsed then
						found[github.key(ref)] = parsed
					end
				end
			end
		end
	end
	return found
end

function github.releaseKey(ref: ReleaseRef): string
	local host = if ref.host and ref.host ~= "github.com" then `{ref.host}/` else ""
	return string.lower(`{host}{ref.owner}/{ref.name}`) .. `@{ref.tag}`
end

function github.releaseRefOf(source: refs.Ref, defaultOwner: string): ReleaseRef?
	local repo, tag = source.repo, source.tag
	if source.kind ~= "github-release" or type(repo) ~= "string" or type(tag) ~= "string" then
		return nil
	end
	local owner, name = repo:match("^([^/]+)/([^/]+)$")
	return { owner = owner or defaultOwner, name = name or repo, tag = tag, host = str(source.host) }
end

function github.fetchReleases(run: CommandRunner, wanted: { ReleaseRef }): { [string]: ReleaseState }
	local found: { [string]: ReleaseState } = {}
	local byHost: { [string]: { ReleaseRef } } = {}
	for _, ref in wanted do
		local host = ref.host or "github.com"
		byHost[host] = byHost[host] or {}
		table.insert(byHost[host], ref)
	end
	for host, hostRefs in byHost do
		for start = 1, #hostRefs, BATCH_SIZE do
			local parts = {}
			local batch: { [string]: ReleaseRef } = {}
			for index = start, math.min(start + BATCH_SIZE - 1, #hostRefs) do
				local ref = hostRefs[index]
				assert(
					ref.owner:match(NAME_PATTERN) and ref.name:match(NAME_PATTERN),
					`invalid repository {ref.owner}/{ref.name}`
				)
				local alias = `r{index}`
				batch[alias] = ref
				table.insert(
					parts,
					`{alias}: repository(owner: "{ref.owner}", name: "{ref.name}") \{ release(tagName: {json.serialize(
						ref.tag
					)}) \{ name url publishedAt isDraft isPrerelease } }`
				)
			end
			local data = query(run, `query \{ {table.concat(parts, " ")} }`, if host == "github.com" then nil else host)
			if data then
				for alias, ref in batch do
					local repository = json.asObject(data[alias])
					local release = if repository then json.asObject(repository.release) else nil
					local url = if release then str(release.url) else nil
					if release and url then
						found[github.releaseKey(ref)] = {
							name = str(release.name),
							url = url,
							publishedAt = str(release.publishedAt),
							draft = release.isDraft == true,
							prerelease = release.isPrerelease == true,
						}
					end
				end
			end
		end
	end
	return found
end

local function pullList(nodes: json.Array?): { PullState }
	local out: { PullState } = {}
	for _, raw in nodes or {} do
		local object = json.asObject(raw)
		local repository = if object then json.asObject(object.repository) else nil
		local owner = if repository then json.asObject(repository.owner) else nil
		local name = if repository then str(repository.name) else nil
		local login = if owner then str(owner.login) else nil
		if object and name and login then
			local parsed = pullFromObject(object, login, name)
			if parsed then
				table.insert(out, parsed)
			end
		end
	end
	return out
end

export type IssueState = { owner: string, name: string, number: number, title: string, url: string, host: string? }

local function searchPage(
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
		if info then str(info.endCursor) else nil,
		if info then info.hasNextPage == true else false
end

local function listed(repos: { string }?, name: string): boolean
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

function github.involved(
	run: CommandRunner,
	host: string,
	owners: { string },
	since: string,
	include: { string }?,
	exclude: { string }?
): ({ PullState }, { IssueState }, string)
	local viewerData = assert(query(run, "query { viewer { login } }", host), `could not fetch GitHub viewer on {host}`)
	local viewer = json.asObject(viewerData.viewer)
	local login = assert(if viewer then str(viewer.login) else nil, `could not fetch GitHub viewer on {host}`)
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
				local nodes, nextCursor, more = searchPage(run, host, `{filter} user:{owner}`, cursor)
				for _, raw in nodes do
					count += 1
					local object = json.asObject(raw)
					local repository = if object then json.asObject(object.repository) else nil
					local repositoryOwner = if repository then json.asObject(repository.owner) else nil
					local name = if repository then str(repository.name) else nil
					local actualOwner = if repositoryOwner then str(repositoryOwner.login) else nil
					if not object or not name or not actualOwner or actualOwner:lower() ~= owner:lower() then
						continue
					end
					if include and not listed(include, name) or listed(exclude, name) then
						continue
					end
					local number = object.number
					if type(number) ~= "number" then
						continue
					end
					local key = github.key({ host = host, owner = actualOwner, name = name, number = number })
					if seen[key] then
						continue
					end
					local pull = pullFromObject(object, actualOwner, name, host)
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

function github.authoredOpen(run: CommandRunner): ({ PullState }, string)
	local data = query(
		run,
		`query \{ viewer \{ login pullRequests(first: 100, states: OPEN, orderBy: \{field: UPDATED_AT, direction: DESC}) \{ nodes \{ {PULL_FIELDS} repository \{ name owner \{ login } } } } } }`
	)
	local viewer = if data then json.asObject(data.viewer) else nil
	assert(viewer and type(viewer.login) == "string", "could not fetch GitHub viewer")
	local pulls = json.asObject(viewer.pullRequests)
	return pullList(if pulls then json.asArray(pulls.nodes) else nil), viewer.login
end

function github.reviewRequested(run: CommandRunner): { PullState }
	local data = query(
		run,
		`query \{ search(query: "is:open is:pr review-requested:@me archived:false", type: ISSUE, first: 50) \{ nodes \{ ... on PullRequest \{ {PULL_FIELDS} repository \{ name owner \{ login } } } } } }`
	)
	local search = if data then json.asObject(data.search) else nil
	return pullList(if search then json.asArray(search.nodes) else nil)
end

local function requestedFrom(pull: PullState, viewer: string): boolean
	for _, login in pull.requestedReviewers do
		if login:lower() == viewer:lower() then
			return true
		end
	end
	return false
end

function github.desired(pull: PullState, status: string, who: string?, viewer: string): (string, string?)
	if pull.state == "MERGED" then
		return "done", nil
	elseif pull.state == "CLOSED" then
		return if status == "done" then "done" else "deferred", nil
	elseif status == "blocked" or status == "deferred" then
		return status, who
	elseif pull.author:lower() ~= viewer:lower() then
		return "review", if requestedFrom(pull, viewer) then "you" else nil
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
	local keys: { Ref } = {}
	local releases: { ReleaseRef } = {}
	for _, item in doc.nodes do
		for _, entry in github.pullSources(item, doc.settings.githubOwner) do
			table.insert(keys, entry.key)
		end
		if item.type == "task" then
			for _, source in refs.ofKind(item, "github-release") do
				local ref = github.releaseRefOf(source, doc.settings.githubOwner)
				if ref then
					table.insert(releases, ref)
				end
			end
		end
	end
	local authored, viewer = github.authoredOpen(run)
	return {
		pulls = github.fetch(run, keys),
		releases = if #releases > 0 then github.fetchReleases(run, releases) else {},
		authored = authored,
		reviews = github.reviewRequested(run),
		viewer = viewer,
		discover = discover,
	}
end

function github.recorded(pull: PullState, viewer: string, checkedAt: string): json.Object
	local result = json.object({
		state = pull.state,
		draft = pull.draft,
		title = pull.title,
		url = pull.url,
		author = pull.author,
		mine = pull.author:lower() == viewer:lower(),
		requestedFromYou = requestedFrom(pull, viewer),
		updatedAt = pull.updatedAt,
		additions = pull.additions,
		deletions = pull.deletions,
		checkedAt = checkedAt,
	})
	result.reviewDecision = pull.reviewDecision
	result.checks = pull.checks
	result.mergeStateStatus = pull.mergeState
	if #pull.approvers > 0 then
		local approvers: json.Array = {}
		for _, login in pull.approvers do
			table.insert(approvers, login)
		end
		result.approvers = approvers
	end
	return result
end

local recorded = github.recorded

local function record(item: Item, pull: PullState, viewer: string, checkedAt: string): refs.Ref
	local driver = assert(refs.driver(item))
	driver.state = recorded(pull, viewer, checkedAt)
	driver.branch = pull.branch
	return driver
end

local function resolvedTicket(item: Item): boolean
	for _, ref in refs.list(item) do
		local state = json.asObject(ref.state)
		if ref.kind == "jira" and state and state.statusCategory == "done" then
			return true
		end
	end
	return false
end

--- A card's status from all its pull requests: the topmost open one decides; otherwise any merge finishes the
--- card, and a card whose pull requests all closed is deferred. A resolved ticket finishes a card with no open
--- pull request.
function github.combined(
	item: Item,
	pulls: { PullState },
	status: string,
	who: string?,
	viewer: string
): (string, string?)
	local open: PullState? = nil
	local merged = false
	for _, pull in pulls do
		if pull.state == "OPEN" then
			open = pull
		elseif pull.state == "MERGED" then
			merged = true
		end
	end
	if open then
		return github.desired(open, status, who, viewer)
	elseif merged or resolvedTicket(item) then
		return "done", nil
	end
	return github.desired(pulls[#pulls], status, who, viewer)
end

local function repoName(doc: Doc, pull: PullState): string
	return if pull.owner:lower() == doc.settings.githubOwner:lower() then pull.name else `{pull.owner}/{pull.name}`
end

--- Callers add a card next, so the app is asked to place a new group or tidy an existing one.
local function ensureGroup(doc: Doc, id: string, label: string, blurb: string)
	local group = graph.find(doc, id)
	if not group then
		table.insert(doc.nodes, {
			id = id,
			type = "cluster",
			position = graph.nextSlot(doc, nil),
			data = json.object({ kind = "cluster", label = label, blurb = blurb, layout = "pending" }),
		})
	elseif group.data.layout == nil then
		group.data.layout = "refit"
	end
end

local function stacked(parent: PullState, child: PullState): boolean
	return parent.owner:lower() == child.owner:lower()
		and parent.name:lower() == child.name:lower()
		and parent.number ~= child.number
		and parent.headRefName ~= ""
		and parent.headRefName == child.baseRefName
end

local function syncStackLinks(doc: Doc, fetched: Fetched, report: Report)
	local pulls = table.clone(fetched.pulls)
	for _, list in { fetched.authored, fetched.reviews } do
		for _, pull in list do
			local key = github.key(pull)
			if not pulls[key] then
				pulls[key] = pull
			end
		end
	end
	local cards: { { id: string, pull: PullState } } = {}
	local byId: { [string]: PullState } = {}
	for _, item in doc.nodes do
		for _, entry in github.pullSources(item, doc.settings.githubOwner) do
			local pull = pulls[github.key(entry.key)]
			if pull then
				table.insert(cards, { id = item.id, pull = pull })
			end
		end
		local ref = github.refFor(item, doc.settings.githubOwner)
		local pull = if ref then pulls[github.key(ref)] else nil
		if pull then
			byId[item.id] = pull
		end
	end
	for index = #doc.links, 1, -1 do
		local link = doc.links[index]
		if link.origin ~= "stack" then
			continue
		end
		local parent, child = byId[link.from], byId[link.to]
		if parent and child and parent.state == "OPEN" and child.state == "OPEN" and not stacked(parent, child) then
			table.remove(doc.links, index)
			table.insert(report.unlinked, { from = link.from, to = link.to })
		end
	end
	for _, parent in cards do
		for _, child in cards do
			if parent.id == child.id or not stacked(parent.pull, child.pull) then
				continue
			end
			local exists = false
			for _, link in doc.links do
				if
					(link.from == parent.id and link.to == child.id) or (link.from == child.id and link.to == parent.id)
				then
					exists = true
					break
				end
			end
			if not exists then
				graph.link(doc, parent.id, child.id, "blocks").origin = "stack"
				table.insert(report.linked, { from = parent.id, to = child.id })
			end
		end
	end
end

--- Records what GitHub has for each release source, and whether any of them is published.
local function recordReleases(doc: Doc, item: Item, fetched: Fetched, checkedAt: string): boolean
	if item.type ~= "task" or not fetched.releases then
		return false
	end
	local published = false
	for _, source in refs.ofKind(item, "github-release") do
		local ref = github.releaseRefOf(source, doc.settings.githubOwner)
		if not ref then
			continue
		end
		local release = fetched.releases[github.releaseKey(ref)]
		local state = json.object({ checkedAt = checkedAt })
		if release then
			state.name, state.url, state.publishedAt = release.name, release.url, release.publishedAt
			state.draft, state.prerelease = release.draft, release.prerelease
			published = published or (release.publishedAt ~= nil and not release.draft)
		end
		source.state = state
	end
	return published
end

function github.apply(doc: Doc, fetched: Fetched, checkedAt: string): Report
	local report: Report =
		{ changes = {}, missing = {}, added = {}, reviewAdded = {}, linked = {}, unlinked = {}, checked = 0 }
	local onCanvas: { [string]: boolean } = {}
	for _, item in doc.nodes do
		local published = recordReleases(doc, item, fetched, checkedAt)
		local entries = github.pullSources(item, doc.settings.githubOwner)
		if #entries == 0 then
			local status = str(item.data.status) or "todo"
			if published and status ~= "done" and item.data.itemKind ~= "gate" then
				report.checked += 1
				local who = str(item.data.who)
				table.insert(report.changes, {
					id = item.id,
					label = graph.label(item),
					fromStatus = status,
					toStatus = "done",
					fromWho = who,
					closed = false,
				})
				item.data.status, item.data.who = "done", nil
			end
			continue
		end
		local found: { PullState } = {}
		for _, entry in entries do
			local key = github.key(entry.key)
			onCanvas[key] = true
			local pull = fetched.pulls[key]
			if pull then
				entry.source.state = recorded(pull, fetched.viewer, checkedAt)
				entry.source.branch = pull.branch or entry.source.branch
				table.insert(found, pull)
			end
		end
		if #found == 0 then
			table.insert(report.missing, item.id)
			continue
		end
		report.checked += 1
		local status, who = str(item.data.status) or "todo", str(item.data.who)
		local nextStatus, nextWho = github.combined(item, found, status, who, fetched.viewer)
		if nextStatus ~= status or nextWho ~= who then
			table.insert(report.changes, {
				id = item.id,
				label = graph.label(item),
				fromStatus = status,
				toStatus = nextStatus,
				fromWho = who,
				toWho = nextWho,
				closed = nextStatus == "deferred" and found[#found].state == "CLOSED",
			})
			item.data.status, item.data.who = nextStatus, nextWho
		end
	end

	for _, pull in fetched.reviews do
		local key = github.key(pull)
		if onCanvas[key] then
			continue
		end
		ensureGroup(doc, REVIEWS_ID, "Review requests", "Pull requests waiting on your review.")
		local status, who = github.desired(pull, "todo", nil, fetched.viewer)
		local item = graph.addItem(doc, pull.title, {
			group = REVIEWS_ID,
			repo = repoName(doc, pull),
			pr = pull.number,
			status = status,
			who = who,
		})
		record(item, pull, fetched.viewer, checkedAt)
		onCanvas[key] = true
		table.insert(report.added, item.id)
		table.insert(report.reviewAdded, item.id)
	end

	local unplaced: json.Array = {}
	for _, pull in fetched.authored do
		local key = github.key(pull)
		if onCanvas[key] then
			continue
		end
		local repo = repoName(doc, pull)
		if fetched.discover then
			ensureGroup(doc, INBOX_ID, "Inbox", "Open pull requests found on GitHub that aren't placed yet.")
			local status, who = github.desired(pull, "todo", nil, fetched.viewer)
			local item = graph.addItem(doc, pull.title, {
				group = INBOX_ID,
				repo = repo,
				pr = pull.number,
				status = status,
				who = who,
			})
			record(item, pull, fetched.viewer, checkedAt)
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
		local leftTime: string = if left then str(left.updatedAt) or "" else ""
		local rightTime: string = if right then str(right.updatedAt) or "" else ""
		return (tonumber((leftTime:gsub("%D", ""))) or 0) > (tonumber((rightTime:gsub("%D", ""))) or 0)
	end)
	doc.github = json.object({ viewer = fetched.viewer, checkedAt = checkedAt, unplaced = unplaced })
	return report
end

return table.freeze(github)
