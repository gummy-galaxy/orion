local applyCheckRuns = require("@root/github/applyCheckRuns")
local fetchCheckRuns = require("@root/github/fetchCheckRuns")
local fetchPulls = require("@root/github/fetchPulls")
local getAuthoredOpen = require("@root/github/getAuthoredOpen")
local getKey = require("@root/github/getKey")
local getRefFor = require("@root/github/getRefFor")
local githubTypes = require("@root/github/types")
local types = require("@root/types")

type PullState = githubTypes.PullState
type Ref = githubTypes.Ref
type Fetched = githubTypes.Fetched
type Doc = types.Doc
type CommandRunner = types.CommandRunner

local function collectPulls(doc: Doc, run: CommandRunner, discover: boolean): Fetched
	local refs: { Ref } = {}

	for _, item in doc.nodes do
		local ref = getRefFor(item)

		if ref then
			table.insert(refs, ref)
		end
	end

	local pulls = fetchPulls(run, refs)
	local failing: { PullState } = {}

	for _, pull in pulls do
		if pull.state == "OPEN" and pull.checkCounts and pull.checkCounts.failed > 0 then
			table.insert(failing, pull)
		end
	end

	-- Only failing pull requests need their jobs by name, to tell optional failures and snoozed jobs apart.
	local checkRuns = if #failing > 0 then fetchCheckRuns(run, failing) else {}

	for _, pull in failing do
		local runs = checkRuns[getKey(pull)]

		if runs then
			applyCheckRuns(pull, runs)
		end
	end

	local authored, viewer = getAuthoredOpen(run)
	return {
		pulls = pulls,
		authored = authored,
		viewer = viewer,
		discover = discover,
	}
end

return collectPulls
