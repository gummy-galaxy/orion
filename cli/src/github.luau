local json = require("@std/json")

local graph = require("@root/graph")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type CommandRunner = types.CommandRunner

export type PullState = {
	owner: string,
	name: string,
	number: number,
	state: string,
	draft: boolean,
	reviewDecision: string?,
	reviewRequests: number,
	title: string,
	url: string,
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

export type Report = {
	changes: { Change },
	missing: { string },
	added: { string },
	checked: number,
}

local BATCH_SIZE = 25
local PULL_FIELDS = "number title url state isDraft reviewDecision reviewRequests { totalCount }"
local NAME_PATTERN = "^[%w%-%._]+$"
local INBOX_ID = "inbox"

local github = {}

function github.key(ref: Ref): string
	return string.lower(`{ref.owner}/{ref.name}#{ref.number}`)
end

-- A repo is either "owner/name" or a bare name under the default owner.
function github.refFor(item: Item, defaultOwner: string): Ref?
	local repo = item.data.repo
	local number = item.data.pr
	if type(repo) ~= "string" or type(number) ~= "number" then
		return nil
	end
	local owner, name = repo:match("^([^/]+)/([^/]+)$")
	return { owner = owner or defaultOwner, name = name or repo, number = number }
end

local function pullFromObject(object: json.Object, owner: string, name: string): PullState?
	local number = object.number
	local state = object.state
	local url = object.url
	if type(number) ~= "number" or type(state) ~= "string" or type(url) ~= "string" then
		return nil
	end
	local requests = json.asObject(object.reviewRequests)
	local count = if requests then requests.totalCount else nil
	local decision = object.reviewDecision
	local title = object.title
	return {
		owner = owner,
		name = name,
		number = number,
		state = state,
		draft = object.isDraft == true,
		reviewDecision = if type(decision) == "string" then decision else nil,
		reviewRequests = if type(count) == "number" then count else 0,
		title = if type(title) == "string" then title else "",
		url = url,
	}
end

-- gh exits non-zero when part of a query fails but still prints the data that resolved.
local function query(run: CommandRunner, text: string): json.Object?
	local ok, response = pcall(run, { "gh", "api", "graphql", "-f", `query={text}` })
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

-- Looks up pull requests in batches, keyed by `github.key`.
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

-- Open pull requests authored by whoever `gh` is signed in as.
function github.authoredOpen(run: CommandRunner): { PullState }
	local data = query(
		run,
		`query \{ viewer \{ pullRequests(first: 100, states: OPEN, orderBy: \{field: UPDATED_AT, direction: DESC}) \{ nodes \{ {PULL_FIELDS} repository \{ name owner \{ login } } } } } }`
	)
	local viewer = if data then json.asObject(data.viewer) else nil
	local pulls = if viewer then json.asObject(viewer.pullRequests) else nil
	local out: { PullState } = {}
	for _, raw in (if pulls then json.asArray(pulls.nodes) else nil) or {} do
		local object = json.asObject(raw)
		local repository = if object then json.asObject(object.repository) else nil
		local owner = if repository then json.asObject(repository.owner) else nil
		local name = if repository then repository.name else nil
		local login = if owner then owner.login else nil
		if object and type(name) == "string" and type(login) == "string" then
			local parsed = pullFromObject(object, login, name)
			if parsed then
				table.insert(out, parsed)
			end
		end
	end
	return out
end

--[[
	What a card should say given its pull request. Merged is done and closed is
	deferred. Blocked and deferred are set by hand for reasons GitHub can't see, so
	they hold while the pull request is open.
]]
function github.desired(pull: PullState, status: string, who: string?): (string, string?)
	if pull.state == "MERGED" then
		return "done", nil
	elseif pull.state == "CLOSED" then
		return if status == "done" then "done" else "deferred", nil
	elseif status == "blocked" or status == "deferred" then
		return status, who
	elseif pull.draft or pull.reviewDecision == "CHANGES_REQUESTED" then
		return "active", "you"
	elseif pull.reviewDecision == "APPROVED" then
		return "review", "you"
	elseif pull.reviewRequests > 0 then
		return "review", "review"
	end
	return "review", "you"
end

local function str(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

export type Fetched = {
	pulls: { [string]: PullState },
	authored: { PullState }?,
}

-- Network work happens here, outside the data lock.
function github.collect(doc: Doc, run: CommandRunner, discover: boolean): Fetched
	local refs: { Ref } = {}
	for _, item in doc.nodes do
		local ref = github.refFor(item, doc.settings.githubOwner)
		if ref then
			table.insert(refs, ref)
		end
	end
	return {
		pulls = github.fetch(run, refs),
		authored = if discover then github.authoredOpen(run) else nil,
	}
end

-- Applies fetched state to a document. Labels stay yours; GitHub's title is kept alongside.
function github.apply(doc: Doc, fetched: Fetched, checkedAt: string): Report
	local report: Report = { changes = {}, missing = {}, added = {}, checked = 0 }
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
		local status = str(item.data.status) or "todo"
		local who = str(item.data.who)
		local nextStatus, nextWho = github.desired(pull, status, who)
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
			item.data.status = nextStatus
			item.data.who = nextWho
		end
		item.data.github = json.object({
			state = pull.state,
			draft = pull.draft,
			reviewDecision = pull.reviewDecision,
			title = pull.title,
			checkedAt = checkedAt,
		})
	end

	for _, pull in fetched.authored or {} do
		local key = github.key({ owner = pull.owner, name = pull.name, number = pull.number })
		if onCanvas[key] then
			continue
		end
		if not graph.find(doc, INBOX_ID) then
			table.insert(doc.nodes, {
				id = INBOX_ID,
				type = "cluster",
				position = graph.nextSlot(doc, nil),
				data = json.object({
					kind = "cluster",
					label = "Inbox",
					blurb = "Open pull requests found on GitHub that aren't placed yet.",
				}),
			})
		end
		local repo = if pull.owner:lower() == doc.settings.githubOwner:lower()
			then pull.name
			else `{pull.owner}/{pull.name}`
		local status, who = github.desired(pull, "todo", nil)
		local item = graph.addItem(
			doc,
			pull.title,
			{ group = INBOX_ID, repo = repo, pr = pull.number, status = status, who = who }
		)
		onCanvas[key] = true
		table.insert(report.added, item.id)
	end
	return report
end

return table.freeze(github)
