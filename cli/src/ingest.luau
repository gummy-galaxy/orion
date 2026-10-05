local json = require("@std/json")

local github = require("@root/github")
local graph = require("@root/graph")
local mentions = require("@root/mentions")
local refs = require("@root/refs")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Source = types.Source
type CommandRunner = types.CommandRunner

export type SourceReport = { id: string, added: number, updated: number, linked: number, failed: string? }
export type Report = { sources: { SourceReport } }
type JiraIssue = {
	key: string,
	summary: string,
	status: string,
	category: string,
	issueType: string,
	epicKey: string?,
	epicSummary: string?,
	updated: string?,
	description: string?,
	links: { JiraLink },
}
--- One of Jira's own issue links, from this ticket's side. `upstream` means the other ticket comes first.
type JiraLink = { key: string, kind: string, upstream: boolean }
type Worktree = { repo: string, branch: string, lastActivity: number, onDefault: boolean }
type Session = { repo: string, branch: string, title: string, updatedAt: number }
type Result = {
	source: Source,
	report: SourceReport,
	pulls: { github.PullState }?,
	issues: { github.IssueState }?,
	viewer: string?,
	jira: { JiraIssue }?,
	worktrees: { Worktree }?,
	sessions: { Session }?,
}

local ingest = {}

local function str(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

local function commandJson(run: CommandRunner, argv: { string }): json.Value
	local result = run(argv)
	assert(result.ok, `{argv[1]} failed: {result.stderr}`)
	local ok, value = pcall(json.deserialize, result.stdout)
	assert(ok, `{argv[1]} returned invalid JSON`)
	return value :: json.Value
end

--- Plain text from a Jira description, which is either a string or an Atlassian document. Link targets count as text.
local function documentText(value: json.Value?): string?
	if type(value) == "string" then
		return value
	end
	local parts: { string } = {}
	local function walk(node: json.Value?)
		local object = json.asObject(node)
		if not object then
			for _, child in json.asArray(node) or {} do
				walk(child)
			end
			return
		end
		table.insert(parts, str(object.text) or "")
		local attrs = json.asObject(object.attrs)
		local url = if attrs then str(attrs.url) or str(attrs.href) else nil
		if url then
			table.insert(parts, ` {url} `)
		end
		for _, raw in json.asArray(object.marks) or {} do
			local mark = json.asObject(raw)
			local markAttrs = if mark then json.asObject(mark.attrs) else nil
			local href = if markAttrs then str(markAttrs.href) else nil
			if href then
				table.insert(parts, ` {href} `)
			end
		end
		walk(object.content)
		if object.type == "paragraph" or object.type == "listItem" or object.type == "heading" then
			table.insert(parts, "\n")
		end
	end
	walk(value)
	local text = table.concat(parts)
	return if text ~= "" then text else nil
end

local function jiraLinks(fields: json.Object?): { JiraLink }
	local out: { JiraLink } = {}
	for _, raw in (if fields then json.asArray(fields.issuelinks) else nil) or {} do
		local link = json.asObject(raw)
		local linkType = if link then json.asObject(link.type) else nil
		local blocks = linkType ~= nil and (str(linkType.name) or ""):lower() == "blocks"
		for _, side in { "outwardIssue", "inwardIssue" } do
			local other = if link then json.asObject(link[side]) else nil
			local key = if other then str(other.key) else nil
			if key then
				-- An outward "blocks" link means this ticket blocks the other one.
				table.insert(out, {
					key = key,
					kind = if blocks then "blocks" else "related",
					upstream = side == "inwardIssue" or not blocks,
				})
			end
		end
	end
	return out
end

local function jiraIssues(value: json.Value): { JiraIssue }
	local root = json.asObject(value)
	local array = if root then json.asArray(root.issues) else json.asArray(value)
	assert(array, "Jira response must be an array or contain issues")
	local out = {}
	for _, raw in array do
		local issue = json.asObject(raw)
		local fields = if issue then json.asObject(issue.fields) else nil
		local key = if issue then str(issue.key) else nil
		local summary = (if issue then str(issue.summary) else nil) or (if fields then str(fields.summary) else nil)
		local status = if fields then json.asObject(fields.status) else nil
		local category = if status then json.asObject(status.statusCategory) else nil
		local categoryKey = (if issue then str(issue.statusCategory) else nil)
			or (if category then str(category.key) else nil)
		local issueType = if fields then json.asObject(fields.issuetype) else nil
		if not key or not summary then
			continue
		end
		local epic = if fields then json.asObject(fields.epic) or json.asObject(fields.parent) else nil
		local epicFields = if epic then json.asObject(epic.fields) else nil
		table.insert(out, {
			key = key,
			summary = summary,
			status = (if issue then str(issue.status) else nil) or (if status then str(status.name) else nil) or "",
			category = if categoryKey == "done" or categoryKey == "indeterminate" then categoryKey else "new",
			issueType = (if issue then str(issue.type) else nil)
				or (if issueType then str(issueType.name) else nil)
				or "",
			epicKey = (if issue then str(issue.epicKey) else nil) or (if epic then str(epic.key) else nil),
			epicSummary = (if issue then str(issue.epicSummary) else nil) or (if epic
				then str(epic.summary) or str(epic.name) or (if epicFields then str(epicFields.summary) else nil)
				else nil),
			updated = (if issue then str(issue.updatedAt) else nil) or (if fields then str(fields.updated) else nil),
			description = documentText(
				(if fields then fields.description else nil) or (if issue then issue.description else nil)
			),
			links = jiraLinks(fields),
		})
	end
	return out
end

local function hopData(run: CommandRunner, source: Source): ({ Worktree }, { Session })
	local binary = assert(source.command and source.command[1], "hop source needs a command")
	local list = json.asObject(commandJson(run, { binary, "list", "--json" }))
	assert(list, "hop list returned invalid JSON")
	local worktrees: { Worktree } = {}
	for _, raw in json.asArray(list.worktrees) or {} do
		local tree = json.asObject(raw)
		local repository = if tree then json.asObject(tree.repository) else nil
		local repo: string? = nil
		if repository then
			repo = str(repository.remote) or str(repository.name)
		end
		local branch = if tree then str(tree.branch) else nil
		if tree and repo and branch then
			table.insert(worktrees, {
				repo = repo :: string,
				branch = branch,
				lastActivity = if type(tree.lastActivity) == "number" then tree.lastActivity else 0,
				onDefault = tree.onDefaultBranch == true,
			})
		end
	end
	local recent = json.asArray(commandJson(run, { binary, "recent", "--json", "--limit", "50" }))
	assert(recent, "hop recent returned invalid JSON")
	local sessions: { Session } = {}
	for _, raw in recent do
		local session = json.asObject(raw)
		local repo = if session then str(session.repository) else nil
		local branch = if session then str(session.branch) else nil
		local title = if session then str(session.title) else nil
		if session and repo and branch and title then
			table.insert(sessions, {
				repo = repo,
				branch = branch,
				title = title:sub(1, 120),
				updatedAt = if type(session.updatedAt) == "number" then session.updatedAt else 0,
			})
		end
	end
	return worktrees, sessions
end

local function unix(iso: string): number
	local year, month, day, hour, minute, second = iso:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
	if not year then
		return os.time()
	end
	local localTime = os.time({
		year = tonumber(year) :: number,
		month = tonumber(month) :: number,
		day = tonumber(day) :: number,
		hour = tonumber(hour) :: number,
		min = tonumber(minute) :: number,
		sec = tonumber(second) :: number,
	})
	local utc = os.date("!*t", localTime)
	return localTime
		+ os.difftime(
			localTime,
			os.time({ year = utc.year, month = utc.month, day = utc.day, hour = utc.hour, min = utc.min, sec = utc.sec })
		)
end

function ingest.collect(doc: Doc, run: CommandRunner, now: string, selected: string?): { Result }
	local results: { Result } = {}
	local since = os.date("!%Y-%m-%d", unix(now) - 14 * 86400)
	local found = false
	for _, source in doc.settings.sources do
		if selected and source.id ~= selected then
			continue
		end
		found = true
		local result: Result = { source = source, report = { id = source.id, added = 0, updated = 0, linked = 0 } }
		local ok, err = pcall(function()
			if source.kind == "github" then
				result.pulls, result.issues, result.viewer = github.involved(
					run,
					assert(source.host),
					assert(source.owners),
					since,
					source.include,
					source.exclude
				)
			elseif source.kind == "jira" then
				result.jira = jiraIssues(commandJson(run, assert(source.command)))
			elseif source.kind == "hop" then
				result.worktrees, result.sessions = hopData(run, source)
			else
				error(`unknown source kind {source.kind}`)
			end
		end)
		if not ok then
			result.report.failed = tostring(err)
		end
		table.insert(results, result)
	end
	assert(found or not selected, `no source with id "{selected}"`)
	return results
end

local function repoName(doc: Doc, owner: string, name: string): string
	return if owner:lower() == doc.settings.githubOwner:lower() then name else `{owner}/{name}`
end

local function fullRepo(doc: Doc, repo: string): string
	return (if repo:find("/", 1, true) then repo else `{doc.settings.githubOwner}/{repo}`):lower()
end

local function refRepo(doc: Doc, ref: refs.Ref): string?
	local repo = str(ref.repo)
	return if repo then fullRepo(doc, repo) else nil
end

local function refHost(ref: refs.Ref): string
	return str(ref.host) or "github.com"
end

local function findNumbered(doc: Doc, kind: string, repo: string, number: number, host: string): Item?
	for _, item in doc.nodes do
		if item.type ~= "task" then
			continue
		end
		for _, ref in refs.ofKind(item, kind) do
			if ref.number == number and refRepo(doc, ref) == repo and refHost(ref) == host then
				return item
			end
		end
	end
	return nil
end

local function findPull(doc: Doc, repo: string, number: number, host: string): Item?
	return findNumbered(doc, "github-pr", repo, number, host)
end

local function findIssue(doc: Doc, repo: string, number: number, host: string): Item?
	return findNumbered(doc, "github-issue", repo, number, host)
end

local function findBranch(doc: Doc, repo: string, branch: string): Item?
	for _, item in doc.nodes do
		if item.type ~= "task" or #refs.ofKind(item, "github-issue") > 0 then
			continue
		end
		for _, ref in refs.list(item) do
			if
				(ref.kind == "github-pr" or ref.kind == "hop")
				and ref.branch == branch
				and refRepo(doc, ref) == repo
			then
				return item
			end
		end
	end
	return nil
end

local function newRef(fields: { [string]: json.Value }): refs.Ref
	local ref = json.object({})
	for key, value in fields do
		ref[key] = value
	end
	return ref
end

local function newItem(doc: Doc, label: string, status: string, who: string?): Item
	if not graph.find(doc, "unsorted") then
		table.insert(doc.nodes, {
			id = "unsorted",
			type = "cluster",
			position = graph.nextSlot(doc, nil),
			data = json.object({ kind = "cluster", label = "Unsorted" }),
		})
	end
	-- New cards land in a row; the app tidies the group when it next opens.
	local unsorted = graph.get(doc, "unsorted")
	if unsorted.data.layout == nil then
		unsorted.data.layout = "refit"
	end
	return graph.addItem(doc, label, { group = "unsorted", status = status, who = who })
end

local function mark(report: SourceReport, existing: Item?)
	if existing then
		report.updated += 1
	else
		report.added += 1
	end
end

local function jiraDone(item: Item): boolean
	for _, ref in refs.ofKind(item, "jira") do
		local state = json.asObject(ref.state)
		if state and state.statusCategory == "done" then
			return true
		end
	end
	return false
end

function ingest.apply(doc: Doc, results: { Result }, now: string): Report
	local pendingPulls: { { pull: github.PullState, item: Item, report: SourceReport } } = {}
	local pendingJira: { { jira: JiraIssue, item: Item, report: SourceReport } } = {}
	-- Tickets first, so pull requests that name one can join its card.
	for _, result in results do
		if result.report.failed then
			continue
		end
		local id = result.source.id
		for _, jira in result.jira or {} do
			local item = mentions.findJira(doc, jira.key)
			mark(result.report, item)
			local card = item or newItem(doc, jira.summary, "todo", "you")
			local status = if jira.category == "done"
				then "done"
				elseif jira.category == "indeterminate" then "active"
				else "todo"
			card.data.label = jira.summary
			-- Pull requests stacked on the ticket drive the card until the ticket resolves.
			if #refs.pulls(card) == 0 or status == "done" then
				card.data.status = status
				card.data.who = if status == "done" then nil else "you"
			end
			local ref = refs.attach(card, newRef({ kind = "jira", key = jira.key }))
			ref.url = if result.source.browse then `{result.source.browse}/{jira.key}` else ref.url
			local state = json.object({ status = jira.status, statusCategory = jira.category, type = jira.issueType })
			state.epicKey = jira.epicKey
			state.epicSummary = jira.epicSummary
			state.updatedAt = jira.updated
			ref.state = state
			refs.via(ref, id)
			table.insert(pendingJira, { jira = jira, item = card, report = result.report })
		end
	end
	for _, result in results do
		if result.report.failed or result.source.kind == "hop" then
			continue
		end
		local id = result.source.id
		for _, pull in result.pulls or {} do
			local repo = string.lower(`{pull.owner}/{pull.name}`)
			local host = pull.host or "github.com"
			local existing = findPull(doc, repo, pull.number, host)
			local step = if not existing and pull.branch then findBranch(doc, repo, pull.branch) else nil
			if step and #refs.pulls(step) > 0 then
				step = nil
			end
			local ownKey = if existing or step then nil else mentions.ownKey(pull.title, pull.branch)
			local ticket = if ownKey then mentions.findJira(doc, ownKey) else nil
			local item = existing or step or ticket or newItem(doc, pull.title, "todo", nil)
			mark(result.report, existing or step or ticket)
			if not jiraDone(item) then
				local status, who =
					github.desired(pull, str(item.data.status) or "todo", str(item.data.who), assert(result.viewer))
				item.data.status = status
				item.data.who = who
			end
			if not refs.jira(item) then
				item.data.label = pull.title
			end
			local ref =
				newRef({ kind = "github-pr", repo = repoName(doc, pull.owner, pull.name), number = pull.number })
			ref.host = if host ~= "github.com" then host else nil
			ref = refs.attach(item, ref)
			ref.branch = pull.branch or ref.branch
			ref.state = github.recorded(pull, assert(result.viewer), now)
			refs.via(ref, id)
			table.insert(pendingPulls, { pull = pull, item = item, report = result.report })
		end
		for _, issue in result.issues or {} do
			local repo = string.lower(`{issue.owner}/{issue.name}`)
			local item = findIssue(doc, repo, issue.number, issue.host or "github.com")
			mark(result.report, item)
			local card = item or newItem(doc, issue.title, "todo", "you")
			card.data.label = issue.title
			local ref =
				newRef({ kind = "github-issue", repo = repoName(doc, issue.owner, issue.name), number = issue.number })
			ref.host = if issue.host ~= "github.com" then issue.host else nil
			ref = refs.attach(card, ref)
			ref.state = json.object({ title = issue.title, url = issue.url })
			refs.via(ref, id)
		end
	end
	local cutoff = unix(now) - 21 * 86400
	-- Hop sees every local checkout, so keep only work owned by this canvas's GitHub sources.
	local owners: { [string]: boolean } = {}
	for _, source in doc.settings.sources do
		if source.kind == "github" then
			for _, owner in source.owners or {} do
				owners[owner:lower()] = true
			end
		end
	end
	local knownRepos: { [string]: boolean } = {}
	for _, item in doc.nodes do
		for _, pull in if item.type == "task" then refs.pulls(item) else {} do
			local known = str(pull.repo)
			if known and pull.state ~= nil then
				knownRepos[(known:match("([^/]+)$") or known):lower()] = true
			end
		end
	end
	local function hopRepo(raw: string): string
		if not raw:find("/", 1, true) then
			return raw
		end
		local repo = fullRepo(doc, raw)
		return if repo:match("^([^/]+)/") == doc.settings.githubOwner:lower()
			then repo:match("/([^/]+)$") :: string
			else raw
	end
	local function hopSource(card: Item, raw: string, branch: string): refs.Ref
		local ref = refs.attach(card, newRef({ kind = "hop", repo = hopRepo(raw), branch = branch }))
		ref.state = json.asObject(ref.state) or json.object({})
		return ref
	end
	local function inScope(name: string): boolean
		if next(owners) == nil then
			return true
		end
		local owner = name:match("^([^/]+)/")
		if owner then
			return owners[owner:lower()] == true
		end
		-- Without an owner, only trust repositories GitHub already put on the canvas.
		return knownRepos[name:lower()] == true
	end
	for _, result in results do
		if result.report.failed or result.source.kind ~= "hop" then
			continue
		end
		local cleared: { [string]: boolean } = {}
		for _, tree in result.worktrees or {} do
			if tree.onDefault or tree.lastActivity < cutoff or not inScope(tree.repo) then
				continue
			end
			local repo = fullRepo(doc, tree.repo)
			local item = findBranch(doc, repo, tree.branch)
			mark(result.report, item)
			if not item then
				local label = tree.branch:gsub("([A-Z][A-Z0-9]*)%-(%d+)", "%1\1%2"):gsub("[-/]", " "):gsub("\1", "-")
				item = newItem(doc, label, "active", "you")
			end
			local card = assert(item)
			local ref = hopSource(card, tree.repo, tree.branch)
			local activity = assert(json.asObject(ref.state))
			local stamp = os.date("!%Y-%m-%dT%H:%M:%SZ", tree.lastActivity)
			if stamp > (str(activity.lastActiveAt) or "") then
				activity.lastActiveAt = stamp
			end
			activity.sessions = {}
			cleared[card.id] = true
			refs.via(ref, result.source.id)
		end
		for _, session in result.sessions or {} do
			local item = findBranch(doc, fullRepo(doc, session.repo), session.branch)
			if not item then
				continue
			end
			local ref = hopSource(item, session.repo, session.branch)
			local activity = assert(json.asObject(ref.state))
			if not cleared[item.id] then
				activity.sessions = {}
				cleared[item.id] = true
			end
			local latest = if type(activity.lastActiveAt) == "string" then activity.lastActiveAt else ""
			local stamp = os.date("!%Y-%m-%dT%H:%M:%SZ", session.updatedAt)
			if stamp > latest then
				activity.lastActiveAt = stamp
			end
			local titles = json.asArray(activity.sessions) or {}
			if not table.find(titles, session.title) and #titles < 3 then
				table.insert(titles, session.title)
			end
			activity.sessions = titles
			refs.via(ref, result.source.id)
		end
	end
	for _, entry in pendingPulls do
		local pull = entry.pull
		local text = `{pull.title}\n{pull.body or ""}`
		local context = { owner = pull.owner, name = pull.name, host = pull.host }
		entry.report.linked += #mentions.link(doc, entry.item, text, context)
	end
	for _, entry in pendingJira do
		local count = #mentions.link(doc, entry.item, entry.jira.description or "", nil)
		for _, link in entry.jira.links do
			local other = mentions.findJira(doc, link.key)
			if other and mentions.connect(doc, entry.item, other, link.kind, link.upstream) then
				count += 1
			end
		end
		entry.report.linked += count
	end
	local reports = {}
	for _, result in results do
		table.insert(reports, result.report)
	end
	return { sources = reports }
end

function ingest.reportJson(report: Report): json.Object
	local entries: json.Array = {}
	for _, source in report.sources do
		local entry =
			json.object({ id = source.id, added = source.added, updated = source.updated, linked = source.linked })
		entry.failed = source.failed
		table.insert(entries, entry)
	end
	return json.object({ sources = entries })
end

return table.freeze(ingest)
