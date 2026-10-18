local fetchPulls = require("@root/github/fetchPulls")
local findBranchCards = require("@root/github/findBranchCards")
local findRef = require("@root/refs/findRef")
local getAuthoredOpen = require("@root/github/getAuthoredOpen")
local getKey = require("@root/github/getKey")
local getRefFor = require("@root/github/getRefFor")
local getString = require("@root/github/getString")
local githubTypes = require("@root/github/types")
local isInSources = require("@root/github/isInSources")
local json = require("@std/json")
local query = require("@root/github/query")
local types = require("@root/types")

type Ref = githubTypes.Ref
type PullState = githubTypes.PullState
type Fetched = githubTypes.Fetched
type Doc = types.Doc
type CommandRunner = types.CommandRunner

local function getViewer(run: CommandRunner): string
	local data = query(run, "query { viewer { login } }")
	local viewer = if data then json.asObject(data.viewer) else nil
	return assert(if viewer then getString(viewer.login) else nil, "could not fetch GitHub viewer")
end

--[[
	Fetches what a refresh needs from GitHub, reading `doc` without changing it so the caller can fetch outside the
	workspace lock. Merged pull requests can't change, so their cards aren't fetched again. Your open pull requests are
	listed with light fields, and only the ones about to become cards, by branch or by `discover`, fetch the full set.
	A failed authored list is reported in `failures` and the cards still refresh.
]]
local function collectPulls(doc: Doc, run: CommandRunner, discover: boolean): Fetched
	local refs: { Ref } = {}
	local onCanvas: { [string]: boolean } = {}
	local failures: { string } = {}

	for _, item in doc.nodes do
		local ref = getRefFor(item)

		if not ref then
			continue
		end

		onCanvas[getKey(ref)] = true
		local recorded = findRef(item, "pull")

		if not recorded or recorded.status ~= "merged" then
			table.insert(refs, ref)
		end
	end

	local didList, authored, viewer = pcall(getAuthoredOpen, run)

	if not didList then
		table.insert(failures, `your open pull requests: {authored}`)
		authored, viewer = {}, getViewer(run)
	end

	for _, pull in authored :: { PullState } do
		if onCanvas[getKey(pull)] or not isInSources(doc, pull) then
			continue
		end

		if discover or #findBranchCards(doc, pull) == 1 then
			table.insert(refs, { owner = pull.owner, name = pull.name, number = pull.number })
		end
	end

	local result = fetchPulls(run, refs)

	for _, failure in result.failures do
		table.insert(failures, failure)
	end

	return {
		pulls = result.pulls,
		checked = result.checked,
		authored = authored :: { PullState },
		viewer = viewer :: string,
		discover = discover,
		failures = failures,
	}
end

return collectPulls
