local applyCheckRuns = require("@root/sources/github/checks/applyCheckRuns")
local fetchCheckRunsAsync = require("@root/sources/github/api/fetchCheckRunsAsync")
local fetchPullsAsync = require("@root/sources/github/api/fetchPullsAsync")
local findBranchCards = require("@root/sources/github/pulls/findBranchCards")
local findRef = require("@root/canvas/refs/findRef")
local getAuthoredOpenAsync = require("@root/sources/github/api/getAuthoredOpenAsync")
local getKey = require("@root/sources/github/refs/getKey")
local getRefFor = require("@root/sources/github/refs/getRefFor")
local getString = require("@root/sources/github/getString")
local githubTypes = require("@root/sources/github/types")
local isInSources = require("@root/sources/github/repositories/isInSources")
local json = require("@std/json")
local queryAsync = require("@root/sources/github/api/queryAsync")
local types = require("@root/types")

type Ref = githubTypes.Ref
type PullState = githubTypes.PullState
type Fetched = githubTypes.Fetched
type Scope = githubTypes.Scope
type Doc = types.Doc
type CommandRunner = types.CommandRunner

local function getViewerAsync(doc: Doc, run: CommandRunner): string
	local recorded = json.asObject(doc.github)
	local known = if recorded then getString(recorded.viewer) else nil

	if known then
		return known
	end

	local data = queryAsync(run, "query { viewer { login } }")
	local viewer = if data then json.asObject(data.viewer) else nil
	return assert(if viewer then getString(viewer.login) else nil, "could not fetch GitHub viewer")
end

--[[
	Fetches what a refresh needs from GitHub, reading `doc` without changing it
	so the caller can fetch outside the workspace lock. Merged pull requests
	can't change, so their cards aren't fetched again. Your open pull requests
	are listed with light fields, and only the ones about to become cards by
	branch fetch the full set. A failed authored list is reported in `failures`
	and the cards still refresh. A `scope` limits the cards fetched to its keys
	and skips the authored list unless it asks for it.
]]
local function collectPullsAsync(doc: Doc, run: CommandRunner, scope: Scope?): Fetched
	local refs: { Ref } = {}
	local onCanvas: { [string]: boolean } = {}
	local failures: { string } = {}

	for _, item in doc.nodes do
		local ref = getRefFor(item)

		if not ref then
			continue
		end

		local key = getKey(ref)
		onCanvas[key] = true
		local recorded = findRef(item, "pull")

		if (not recorded or recorded.status ~= "merged") and (not scope or scope.keys[key]) then
			table.insert(refs, ref)
		end
	end

	local authored: { PullState }? = nil
	local viewer: string? = nil

	if not scope or scope.listAuthored then
		local didList, list, login = pcall(getAuthoredOpenAsync, run)

		if didList then
			authored, viewer = list, login
		else
			table.insert(failures, `your open pull requests: {list}`)
		end
	end

	for _, pull in authored or {} do
		if onCanvas[getKey(pull)] or not isInSources(doc, pull) then
			continue
		end

		if #findBranchCards(doc, pull) == 1 then
			table.insert(refs, { owner = pull.owner, name = pull.name, number = pull.number })
		end
	end

	local result = fetchPullsAsync(run, refs)

	for _, failure in result.failures do
		table.insert(failures, failure)
	end

	local failing: { PullState } = {}

	for _, pull in result.pulls do
		if pull.state == "OPEN" and pull.checkCounts and pull.checkCounts.failed > 0 then
			table.insert(failing, pull)
		end
	end

	-- Only failing pull requests need their jobs by name, to tell optional
	-- failures and snoozed jobs apart.
	local didFetchRuns, checkRuns = pcall(fetchCheckRunsAsync, run, failing)

	if not didFetchRuns then
		table.insert(failures, `jobs of failing pull requests: {checkRuns}`)
	else
		for _, pull in failing do
			local runs = checkRuns[getKey(pull)]

			if runs then
				applyCheckRuns(pull, runs)
			end
		end
	end

	return {
		pulls = result.pulls,
		checked = result.checked,
		authored = authored,
		viewer = viewer or getViewerAsync(doc, run),
		failures = failures,
	}
end

return collectPullsAsync
