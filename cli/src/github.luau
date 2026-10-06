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
}

export type Ref = { owner: string, name: string, number: number }
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
export type Fetched = {
	pulls: { [string]: PullState },
	authored: { PullState },
	reviews: { PullState },
	viewer: string,
	discover: boolean,
}

local BATCH_SIZE = 25
local PULL_FIELDS =
	"number title url state baseRefName headRefName isDraft reviewDecision author { login } updatedAt additions deletions commits(last: 1) { nodes { commit { statusCheckRollup { state } } } } reviewRequests(first: 20) { totalCount nodes { requestedReviewer { ... on User { login } } } }"
local NAME_PATTERN = "^[%w%-%._]+$"
local INBOX_ID = "inbox"
local REVIEWS_ID = "reviews"
local github = {}

function github.key(ref: Ref): string
	return string.lower(`{ref.owner}/{ref.name}#{ref.number}`)
end

function github.refFor(item: Item, defaultOwner: string): Ref?
	local repo = item.data.repo
	local number = item.data.pr
	if type(repo) ~= "string" or type(number) ~= "number" then
		return nil
	end
	local owner, name = repo:match("^([^/]+)/([^/]+)$")
	return { owner = owner or defaultOwner, name = name or repo, number = number }
end

local function str(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

local function pullFromObject(object: json.Object, owner: string, name: string): PullState?
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
		reviewRequests = if requests and type(requests.totalCount) == "number" then requests.totalCount else 0,
		requestedReviewers = requestedReviewers,
		title = str(object.title) or "",
		url = url,
		author = if author then str(author.login) or "" else "",
		updatedAt = str(object.updatedAt) or "",
		additions = if type(object.additions) == "number" then object.additions else 0,
		deletions = if type(object.deletions) == "number" then object.deletions else 0,
		checks = if rollup then str(rollup.state) else nil,
	}
end

-- gh can exit non-zero for a partially resolved GraphQL query while retaining usable data.
local function query(run: CommandRunner, source: string): json.Object?
	local ok, response = pcall(run, { "gh", "api", "graphql", "-f", `query={source}` }, nil)
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

function github.fetch(run: CommandRunner, refs: { Ref }): { [string]: PullState }
	local found: { [string]: PullState } = {}
	for start = 1, #refs, BATCH_SIZE do
		local parts = {}
		local batch: { [string]: Ref } = {}
		for index = start, math.min(start + BATCH_SIZE - 1, #refs) do
			local ref = refs[index]
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
		local data = query(run, `query \{ {table.concat(parts, " ")} }`)
		if data then
			for alias, ref in batch do
				local repository = json.asObject(data[alias])
				local pull = if repository then json.asObject(repository.pullRequest) else nil
				local parsed = if pull then pullFromObject(pull, ref.owner, ref.name) else nil
				if parsed then
					found[github.key(ref)] = parsed
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
	local refs: { Ref } = {}
	for _, item in doc.nodes do
		local ref = github.refFor(item, doc.settings.githubOwner)
		if ref then
			table.insert(refs, ref)
		end
	end
	local authored, viewer = github.authoredOpen(run)
	return {
		pulls = github.fetch(run, refs),
		authored = authored,
		reviews = github.reviewRequested(run),
		viewer = viewer,
		discover = discover,
	}
end

local function recorded(pull: PullState, viewer: string, checkedAt: string): json.Object
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
	return result
end

local function repoName(doc: Doc, pull: PullState): string
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
		local ref = github.refFor(item, doc.settings.githubOwner)
		local pull = if ref then pulls[github.key(ref)] else nil
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

function github.apply(doc: Doc, fetched: Fetched, checkedAt: string): Report
	local report: Report =
		{ changes = {}, missing = {}, added = {}, reviewAdded = {}, linked = {}, unlinked = {}, checked = 0 }
	local onCanvas: { [string]: boolean } = {}
	for _, item in doc.nodes do
		local ref = github.refFor(item, doc.settings.githubOwner)
		if not ref then
			continue
		end
		local key = github.key(ref)
		onCanvas[key] = true
		local pull = fetched.pulls[key]
		if not pull then
			table.insert(report.missing, item.id)
			continue
		end
		report.checked += 1
		local status, who = str(item.data.status) or "todo", str(item.data.who)
		local nextStatus, nextWho = github.desired(pull, status, who, fetched.viewer)
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
		item.data.github = recorded(pull, fetched.viewer, checkedAt)
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
			item.data.github = recorded(pull, fetched.viewer, checkedAt)
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
