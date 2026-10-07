local json = require("@std/json")

local github = require("@root/github")
local graph = require("@root/graph")
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
}
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

local function getString(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

local function getCommandJson(run: CommandRunner, argv: { string }): json.Value
	local result = run(argv)
	assert(result.ok, `{argv[1]} failed: {result.stderr}`)
	local succeeded, value = pcall(json.deserialize, result.stdout)
	assert(succeeded, `{argv[1]} returned invalid JSON`)
	return value :: json.Value
end

local function getJiraIssues(value: json.Value): { JiraIssue }
	local root = json.asObject(value)
	local array = if root then json.asArray(root.issues) else json.asArray(value)
	assert(array, "Jira response must be an array or contain issues")
	local result = {}

	for _, raw in array do
		local issue = json.asObject(raw)
		local fields = if issue then json.asObject(issue.fields) else nil
		local key = if issue then getString(issue.key) else nil
		local summary = (if issue then getString(issue.summary) else nil)
			or (if fields then getString(fields.summary) else nil)
		local status = if fields then json.asObject(fields.status) else nil
		local category = if status then json.asObject(status.statusCategory) else nil
		local categoryKey = (if issue then getString(issue.statusCategory) else nil)
			or (if category then getString(category.key) else nil)
		local issueType = if fields then json.asObject(fields.issuetype) else nil

		if not key or not summary then
			continue
		end

		local epic = if fields then json.asObject(fields.epic) or json.asObject(fields.parent) else nil
		local epicFields = if epic then json.asObject(epic.fields) else nil
		table.insert(result, {
			key = key,
			summary = summary,
			status = (if issue then getString(issue.status) else nil) or (if status
				then getString(status.name)
				else nil) or "",
			category = if categoryKey == "done" or categoryKey == "indeterminate" then categoryKey else "new",
			issueType = (if issue then getString(issue.type) else nil) or (if issueType
				then getString(issueType.name)
				else nil) or "",
			epicKey = (if issue then getString(issue.epicKey) else nil) or (if epic then getString(epic.key) else nil),
			epicSummary = (if issue then getString(issue.epicSummary) else nil) or (if epic
				then getString(epic.summary) or getString(epic.name) or (if epicFields
					then getString(epicFields.summary)
					else nil)
				else nil),
			updated = (if issue then getString(issue.updatedAt) else nil)
				or (if fields then getString(fields.updated) else nil),
		})
	end

	return result
end

local function getHopData(run: CommandRunner, source: Source): ({ Worktree }, { Session })
	local binary = assert(source.command and source.command[1], "hop source needs a command")
	local list = json.asObject(getCommandJson(run, { binary, "list", "--json" }))
	assert(list, "hop list returned invalid JSON")
	local worktrees: { Worktree } = {}

	for _, raw in json.asArray(list.worktrees) or {} do
		local tree = json.asObject(raw)
		local repositoryObject = if tree then json.asObject(tree.repository) else nil
		local repositoryName: string? = nil

		if repositoryObject then
			repositoryName = getString(repositoryObject.remote) or getString(repositoryObject.name)
		end

		local branch = if tree then getString(tree.branch) else nil

		if tree and repositoryName and branch then
			table.insert(worktrees, {
				repo = repositoryName :: string,
				branch = branch,
				lastActivity = if type(tree.lastActivity) == "number" then tree.lastActivity else 0,
				onDefault = tree.onDefaultBranch == true,
			})
		end
	end

	local recent = json.asArray(getCommandJson(run, { binary, "recent", "--json", "--limit", "50" }))
	assert(recent, "hop recent returned invalid JSON")
	local sessions: { Session } = {}

	for _, raw in recent do
		local session = json.asObject(raw)
		local repository = if session then getString(session.repository) else nil
		local branch = if session then getString(session.branch) else nil
		local title = if session then getString(session.title) else nil

		if session and repository and branch and title then
			table.insert(sessions, {
				repo = repository,
				branch = branch,
				title = title:sub(1, 120),
				updatedAt = if type(session.updatedAt) == "number" then session.updatedAt else 0,
			})
		end
	end

	return worktrees, sessions
end

local function getUnix(timestamp: string): number
	local year, month, day, hour, minute, second = timestamp:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")

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
	local utcDate = os.date("!*t", localTime)
	return localTime
		+ os.difftime(
			localTime,
			os.time({
				year = utcDate.year,
				month = utcDate.month,
				day = utcDate.day,
				hour = utcDate.hour,
				min = utcDate.min,
				sec = utcDate.sec,
			})
		)
end

function ingest.collect(doc: Doc, run: CommandRunner, now: string, selected: string?): { Result }
	local results: { Result } = {}
	local since = os.date("!%Y-%m-%d", getUnix(now) - 14 * 86400)
	local found = false

	for _, source in doc.settings.sources do
		if selected and source.id ~= selected then
			continue
		end

		found = true
		local result: Result = { source = source, report = { id = source.id, added = 0, updated = 0, linked = 0 } }
		local succeeded, failureMessage = pcall(function()
			if source.kind == "github" then
				result.pulls, result.issues, result.viewer = github.getInvolved(
					run,
					assert(source.host),
					assert(source.owners),
					since,
					source.include,
					source.exclude
				)
			elseif source.kind == "jira" then
				result.jira = getJiraIssues(getCommandJson(run, assert(source.command)))
			elseif source.kind == "hop" then
				result.worktrees, result.sessions = getHopData(run, source)
			else
				error(`unknown source kind {source.kind}`)
			end
		end)

		if not succeeded then
			result.report.failed = tostring(failureMessage)
		end

		table.insert(results, result)
	end

	assert(found or not selected, `no source with id "{selected}"`)
	return results
end

local function getRepositoryName(doc: Doc, owner: string, name: string): string
	return if owner:lower() == doc.settings.githubOwner:lower() then name else `{owner}/{name}`
end

local function getFullRepository(doc: Doc, repository: string): string
	return (if repository:find("/", 1, true) then repository else `{doc.settings.githubOwner}/{repository}`):lower()
end

local function getItemRepository(doc: Doc, item: Item): string?
	local repository = getString(item.data.repo)
	return if repository then getFullRepository(doc, repository) else nil
end

local function getItemHost(item: Item): string
	return getString(item.data.host) or "github.com"
end

local function findPull(doc: Doc, repository: string, number: number, host: string): Item?
	for _, item in doc.nodes do
		if
			item.type == "task"
			and item.data.pr == number
			and getItemRepository(doc, item) == repository
			and getItemHost(item) == host
		then
			return item
		end
	end

	return nil
end

local function findIssue(doc: Doc, repository: string, number: number, host: string): Item?
	for _, item in doc.nodes do
		if
			item.type == "task"
			and item.data.issue == number
			and getItemRepository(doc, item) == repository
			and getItemHost(item) == host
		then
			return item
		end
	end

	return nil
end

local function findBranch(doc: Doc, repository: string, branch: string): Item?
	for _, item in doc.nodes do
		if
			item.type == "task"
			and getItemRepository(doc, item) == repository
			and item.data.branch == branch
			and item.data.issue == nil
		then
			return item
		end
	end

	return nil
end

local function findExternal(doc: Doc, sourceId: string, key: string): Item?
	for _, item in doc.nodes do
		local external = json.asObject(item.data.external)
		if
			item.type == "task"
			and external
			and getString(external.source) == sourceId
			and getString(external.key) == key
		then
			return item
		end
	end

	return nil
end

local function markSourceOn(item: Item, id: string)
	local sources = json.asArray(item.data.sources) or {}

	if not table.find(sources, id) then
		table.insert(sources, id)
	end

	item.data.sources = sources
end

local function applyExternal(item: Item, sourceId: string, fields: json.Object)
	fields.source = sourceId
	item.data.external = fields
	markSourceOn(item, sourceId)
end

local function createItem(doc: Doc, label: string, repository: string?, status: string, who: string?): Item
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

	return graph.addItem(doc, label, { group = "unsorted", repo = repository, status = status, who = who })
end

local function markItem(report: SourceReport, existing: Item?)
	if existing then
		report.updated += 1
	else
		report.added += 1
	end
end

local function linkMention(doc: Doc, from: Item, to: Item, report: SourceReport)
	if from.id == to.id then
		return
	end

	for _, link in doc.links do
		if link.from == from.id and link.to == to.id or link.from == to.id and link.to == from.id then
			return
		end
	end

	graph.link(doc, from.id, to.id, "related").origin = "mention"
	report.linked += 1
end

local function linkMentions(doc: Doc, pull: github.PullState, item: Item, report: SourceReport)
	local text = `{pull.title} {pull.branch or ""} {pull.body or ""}`

	for key in text:upper():gmatch("%f[%w][A-Z][A-Z0-9]*%-%d+%f[^%w]") do
		for _, source in doc.settings.sources do
			if source.kind == "jira" then
				local other = findExternal(doc, source.id, key)

				if other then
					linkMention(doc, other, item, report)
				end
			end
		end
	end

	local repository = string.lower(`{pull.owner}/{pull.name}`)
	local host = pull.host or "github.com"

	for owner, name, number in text:gmatch("([%w_.%-]+)/([%w_.%-]+)#(%d+)") do
		if string.lower(`{owner}/{name}`) == repository then
			local issue = findIssue(doc, repository, tonumber(number) :: number, host)

			if issue then
				linkMention(doc, issue, item, report)
			end
		end
	end

	local bare = text:gsub("[%w_.%-]+/[%w_.%-]+#%d+", "")

	for number in bare:gmatch("#(%d+)") do
		local issue = findIssue(doc, repository, tonumber(number) :: number, host)

		if issue then
			linkMention(doc, issue, item, report)
		end
	end
end

function ingest.apply(doc: Doc, results: { Result }, now: string): Report
	local pendingLinks: { { github.PullState | Item | SourceReport } } = {}

	for _, result in results do
		if result.report.failed or result.source.kind == "hop" then
			continue
		end

		local id = result.source.id

		for _, pull in result.pulls or {} do
			local repository = string.lower(`{pull.owner}/{pull.name}`)
			local host = pull.host or "github.com"
			local existing = findPull(doc, repository, pull.number, host)
			local step = if not existing and pull.branch then findBranch(doc, repository, pull.branch) else nil

			if step and step.data.pr then
				step = nil
			end

			local item = existing
				or step
				or createItem(doc, pull.title, getRepositoryName(doc, pull.owner, pull.name), "todo", nil)
			markItem(result.report, existing or step)
			local status, who = github.getDesired(
				pull,
				getString(item.data.status) or "todo",
				getString(item.data.who),
				assert(result.viewer)
			)
			item.data.label = pull.title
			item.data.itemKind = "pr"
			item.data.repo = getRepositoryName(doc, pull.owner, pull.name)
			item.data.pr = pull.number
			item.data.status = status
			item.data.who = who
			item.data.branch = pull.branch or item.data.branch
			item.data.host = if host ~= "github.com" then host else nil
			item.data.github = github.getRecorded(pull, assert(result.viewer), now)
			markSourceOn(item, id)
			table.insert(pendingLinks, { pull, item, result.report })
		end

		for _, issue in result.issues or {} do
			local repository = string.lower(`{issue.owner}/{issue.name}`)
			local item = findIssue(doc, repository, issue.number, issue.host or "github.com")
			markItem(result.report, item)
			item = item or createItem(doc, issue.title, getRepositoryName(doc, issue.owner, issue.name), "todo", "you")
			item.data.label = issue.title
			item.data.itemKind = "placeholder"
			item.data.repo = getRepositoryName(doc, issue.owner, issue.name)
			item.data.issue = issue.number
			item.data.host = if issue.host ~= "github.com" then issue.host else nil
			markSourceOn(item, id)
		end

		for _, jira in result.jira or {} do
			local item = findExternal(doc, id, jira.key)
			markItem(result.report, item)
			item = item or createItem(doc, jira.summary, nil, "todo", "you")
			local status = if jira.category == "done"
				then "done"
				elseif jira.category == "indeterminate" then "active"
				else "todo"
			item.data.label = jira.summary
			item.data.itemKind = "step"
			item.data.status = status
			item.data.who = if status == "done" then nil else "you"
			local details = json.object({ type = jira.issueType })
			details.epicKey = jira.epicKey
			details.epicSummary = jira.epicSummary
			local fields = json.object({
				key = jira.key,
				status = jira.status,
				isDone = jira.category == "done",
				details = details,
			})
			fields.url = if result.source.browse then `{result.source.browse}/{jira.key}` else nil
			fields.updatedAt = jira.updated
			applyExternal(item, id, fields)
		end
	end

	local cutoff = getUnix(now) - 21 * 86400
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
		local known = getString(item.data.repo)

		if known and item.data.github ~= nil then
			knownRepos[(known:match("([^/]+)$") or known):lower()] = true
		end
	end

	local function isInScope(name: string): boolean
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
			if tree.onDefault or tree.lastActivity < cutoff or not isInScope(tree.repo) then
				continue
			end

			local repository = getFullRepository(doc, tree.repo)
			local item = findBranch(doc, repository, tree.branch)
			markItem(result.report, item)

			if not item then
				local label = tree.branch:gsub("([A-Z][A-Z0-9]*)%-(%d+)", "%1\1%2"):gsub("[-/]", " "):gsub("\1", "-")
				item = createItem(
					doc,
					label,

					if tree.repo:find("/", 1, true)
						then (if repository:match("^([^/]+)/") == doc.settings.githubOwner:lower()
							then repository:match("/([^/]+)$")
							else tree.repo)
						else tree.repo,
					"active",
					"you"
				)
			end

			local card = assert(item)

			if not card.data.pr then
				card.data.itemKind = "step"
			end

			card.data.branch = tree.branch
			local activity = json.asObject(card.data.activity) or json.object({})
			local stamp = os.date("!%Y-%m-%dT%H:%M:%SZ", tree.lastActivity)

			if stamp > (getString(activity.lastActiveAt) or "") then
				activity.lastActiveAt = stamp
			end

			activity.sessions = {}
			cleared[card.id] = true
			card.data.activity = activity
			markSourceOn(card, result.source.id)
		end

		for _, session in result.sessions or {} do
			local item = findBranch(doc, getFullRepository(doc, session.repo), session.branch)

			if not item then
				continue
			end

			local activity = json.asObject(item.data.activity) or json.object({})

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
			item.data.activity = activity
			markSourceOn(item, result.source.id)
		end
	end

	for _, entry in pendingLinks do
		linkMentions(doc, entry[1] :: github.PullState, entry[2] :: Item, entry[3] :: SourceReport)
	end

	local reports = {}

	for _, result in results do
		table.insert(reports, result.report)
	end

	return { sources = reports }
end

function ingest.getReportJson(report: Report): json.Object
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
