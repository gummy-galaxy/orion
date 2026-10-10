local json = require("@std/json")

local findRef = require("@root/refs/findRef")
local getGithubKey = require("@root/refs/getGithubKey")
local setRef = require("@root/refs/setRef")
local types = require("@root/types")

type Item = types.Item
type Source = types.Source

local function getString(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

local function getFullRepo(value: json.Value, owner: string): string?
	local repo = getString(value)

	if not repo or repo == "" then
		return nil
	end

	return if repo:find("/", 1, true) then repo else `{owner}/{repo}`
end

local function getPullStatus(state: json.Object?): string?
	local name = if state then getString(state.state) else nil

	if not name then
		return nil
	end

	return if state and state.draft == true and name == "OPEN" then "draft" else name:lower()
end

local function getPullDetails(state: json.Object?, branch: string?): json.Object?
	if not state then
		return nil
	end

	local details = json.object(state)

	if branch then
		details.branch = branch
	end

	return details
end

local function migrateItem(item: Item, owner: string, sources: { Source })
	local data = item.data
	local recordedSources = json.asArray(data.sources) or {}
	local repo = getFullRepo(data.repo, owner)

	if not repo then
		for _, value in recordedSources do
			local source = json.asObject(value)
			repo = if source then getFullRepo(source.repo, owner) else nil

			if repo then
				break
			end
		end
	end

	if repo then
		data.repo = repo
	end

	local host = getString(data.host) or "github.com"
	local hopSource = "hop"

	for _, source in sources do
		if source.kind == "hop" and table.find(recordedSources, source.id) then
			hopSource = source.id
			break
		end
	end

	local repoOwner: string?, repoName: string?

	if repo then
		repoOwner, repoName = repo:match("^([^/]+)/([^/]+)$")
	end

	local pullNumber = if type(data.pr) == "number" then data.pr else nil
	local github = json.asObject(data.github)

	if repoOwner and repoName and pullNumber then
		setRef(item, {
			source = "github",
			kind = "pull",
			key = getGithubKey(repoOwner, repoName, `#{pullNumber}`, host),
			url = (if github then getString(github.url) else nil) or `https://{host}/{repo}/pull/{pullNumber}`,
			status = getPullStatus(github),
			isDone = if github then github.state == "MERGED" else nil,
			updatedAt = if github then getString(github.updatedAt) else nil,
			details = getPullDetails(github, getString(data.branch)),
		})
	end

	local issue = if type(data.issue) == "number" then data.issue else nil

	if repoOwner and repoName and issue then
		setRef(item, {
			source = "github",
			kind = "issue",
			key = getGithubKey(repoOwner, repoName, `#{issue}`, host),
			url = `https://{host}/{repo}/issues/{issue}`,
		})
	end

	local external = json.asObject(data.external)

	if external and getString(external.source) and getString(external.key) then
		setRef(item, {
			source = external.source :: string,
			kind = "issue",
			key = external.key :: string,
			url = getString(external.url),
			status = getString(external.status),
			isDone = if type(external.isDone) == "boolean" then external.isDone else nil,
			updatedAt = getString(external.updatedAt),
			details = json.asObject(external.details),
		})
	end

	local branch = getString(data.branch)

	if repoOwner and repoName and branch and (not pullNumber or data.activity ~= nil) then
		setRef(item, {
			source = hopSource,
			kind = "branch",
			key = getGithubKey(repoOwner, repoName, `@{branch}`, host),
			details = json.asObject(data.activity) or json.object({}),
		})
	end

	for _, value in recordedSources do
		local source = json.asObject(value)
		local sourceRepo = if source then getFullRepo(source.repo, owner) else nil

		if not source or not sourceRepo then
			continue
		end

		local sourceOwner, sourceName = sourceRepo:match("^([^/]+)/([^/]+)$")

		if not sourceOwner or not sourceName then
			continue
		end

		local sourceKind = getString(source.kind)
		local sourceVia = getString(source.via)
		local sourceNumber = if type(source.number) == "number" then source.number else nil
		local state = json.asObject(source.state)
		local sourceBranch = getString(source.branch)

		if sourceKind == "github-pr" and sourceNumber then
			setRef(item, {
				source = sourceVia or "github",
				kind = "pull",
				key = getGithubKey(sourceOwner, sourceName, `#{sourceNumber}`, host),
				url = (if state then getString(state.url) else nil)
					or `https://{host}/{sourceRepo}/pull/{sourceNumber}`,
				status = getPullStatus(state),
				isDone = if state then state.state == "MERGED" else nil,
				updatedAt = if state then getString(state.updatedAt) else nil,
				details = getPullDetails(state, sourceBranch),
			})
		elseif sourceKind == "github-issue" and sourceNumber then
			setRef(item, {
				source = sourceVia or "github",
				kind = "issue",
				key = getGithubKey(sourceOwner, sourceName, `#{sourceNumber}`, host),
				url = `https://{host}/{sourceRepo}/issues/{sourceNumber}`,
			})
		elseif sourceKind == "hop" and sourceBranch then
			setRef(item, {
				source = sourceVia or hopSource,
				kind = "branch",
				key = getGithubKey(sourceOwner, sourceName, `@{sourceBranch}`, host),
				details = state or json.object({}),
			})
		end
	end

	for _, field in { "pr", "host", "branch", "issue", "external", "github", "activity", "sources" } do
		data[field] = nil
	end

	local itemKind = getString(data.itemKind)

	if itemKind ~= "gate" and itemKind ~= "note" then
		if findRef(item, "pull") then
			data.itemKind = "pr"
		elseif itemKind == nil or itemKind == "pr" then
			data.itemKind = if data.repo ~= nil then "placeholder" else "step"
		end
	end
end

return migrateItem
