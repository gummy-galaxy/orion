local json = require("@std/json")

local adapterTypes = require("@root/sources/types")
local findBranch = require("@root/sources/findBranch")
local findRef = require("@root/canvas/refs/findRef")
local getGithubKey = require("@root/sources/github/refs/getGithubKey")
local getUnix = require("@root/sources/getUnix")
local parseDataAsync = require("@root/sources/hop/parseDataAsync")
local types = require("@root/types")

type Record = adapterTypes.Record
type Context = adapterTypes.Context
type Doc = types.Doc
type Item = types.Item
type Source = types.Source
type CommandRunner = types.CommandRunner

local function collectAsync(source: Source, run: CommandRunner, context: Context): { Record }
	local worktrees, sessions = parseDataAsync(run, context.commands[source.id])
	local doc = context.doc
	local owners: { [string]: boolean } = {}

	for _, configured in doc.settings.sources do
		if configured.kind == "github" then
			for _, owner in configured.owners or {} do
				owners[owner:lower()] = true
			end
		end
	end

	local function resolveRepo(name: string): string?
		local owner = name:match("^([^/]+)/")

		if owner then
			return if next(owners) == nil or owners[owner:lower()] then name else nil
		end

		for _, item in doc.nodes do
			local repo = item.data.repo

			if
				type(repo) == "string"
				and (repo:match("/([^/]+)$") or ""):lower() == name:lower()
				and findRef(item, "pull")
			then
				return repo
			end
		end

		return nil
	end

	local records: { Record } = {}
	local byBranch: { [string]: Record } = {}
	local cleared: { [string]: boolean } = {}
	local cutoff = getUnix(context.now) - 21 * 86400

	local function getRecord(repo: string, branch: string, item: Item?, isUpdateOnly: boolean): Record
		local branchRef = if item then findRef(item, "branch") else nil
		local pull = if item then findRef(item, "pull") else nil
		local activity = if branchRef then json.object(branchRef.details or {}) else json.object({})
		local owner, name = repo:match("^([^/]+)/([^/]+)$")
		local host = if pull then pull.key:match("^([^/]+)/[^/]+/[^/]+#") else nil
		local label = branch:gsub("([A-Z][A-Z0-9]*)%-(%d+)", "%1\1%2"):gsub("[-/]", " "):gsub("\1", "-")
		return {
			ref = {
				source = source.id,
				kind = "branch",
				type = "step",
				key = getGithubKey(assert(owner), assert(name), `@{branch}`, host),
				details = activity,
			},
			label = label,
			repo = repo,
			itemKind = if isUpdateOnly then nil else "step",
			createStatus = "active",
			createWho = "you",
			isUpdateOnly = isUpdateOnly,
			isUncounted = isUpdateOnly,
			setRepoOnUpdate = false,
			setLabelOnUpdate = false,
			keepPullKind = true,
			shouldFindFallbackFirst = true,
			findFallback = function(current: Doc): Item?
				return findBranch(current, repo, branch)
			end,
		}
	end

	for _, worktree in worktrees do
		local repo = resolveRepo(worktree.repo)

		if worktree.onDefault or worktree.lastActivity < cutoff or not repo then
			continue
		end

		local item = findBranch(doc, repo, worktree.branch)
		local record = getRecord(repo, worktree.branch, item, false)
		local activity = assert(record.ref.details)
		local stamp = os.date("!%Y-%m-%dT%H:%M:%SZ", worktree.lastActivity)

		if stamp > (if type(activity.lastActiveAt) == "string" then activity.lastActiveAt else "") then
			activity.lastActiveAt = stamp
		end

		activity.sessions = {}
		local branchKey = `{repo:lower()}@{worktree.branch}`
		byBranch[branchKey] = record
		cleared[branchKey] = true
		table.insert(records, record)
	end

	for _, session in sessions do
		local repo = resolveRepo(session.repo)
		local item = if repo then findBranch(doc, repo, session.branch) else nil
		local branchKey = if repo then `{repo:lower()}@{session.branch}` else ""
		local record = byBranch[branchKey]

		if not item and not record then
			continue
		end

		if not record then
			record = getRecord(assert(repo), session.branch, item, true)
			byBranch[branchKey] = record
			table.insert(records, record)
		end

		local activity = assert(record.ref.details)

		if not cleared[branchKey] then
			activity.sessions = {}
			cleared[branchKey] = true
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
	end

	return records
end

return collectAsync
