local adapterTypes = require("@root/adapters/types")
local applyPulls = require("@root/github/applyPulls")
local applyRepositories = require("@root/github/applyRepositories")
local collectPulls = require("@root/github/collectPulls")
local fetchRepositories = require("@root/github/fetchRepositories")
local githubTypes = require("@root/github/types")
local healRefKeys = require("@root/github/healRefKeys")
local setRepository = require("@root/github/setRepository")
local trackCheckSnoozes = require("@root/checks/trackCheckSnoozes")
local types = require("@root/types")

type Doc = types.Doc
type CommandRunner = types.CommandRunner
type RefreshOptions = adapterTypes.RefreshOptions

local function refresh(doc: Doc, run: CommandRunner, options: RefreshOptions): (Doc) -> githubTypes.Report
	local found = fetchRepositories(doc, run)
	local fetched = collectPulls(doc, run)

	return function(current: Doc): githubTypes.Report
		applyRepositories(current, found, options.now)
		local report = applyPulls(current, fetched, options.now)
		trackCheckSnoozes(current, fetched, options.now)

		-- Keys change last, since the fetched pull requests are keyed by the
		-- names the cards had when they were fetched.
		local function record(pull: githubTypes.PullState)
			if pull.repoId and pull.repoName then
				setRepository(current, pull.host, pull.repoId, pull.repoName, options.now)
			end
		end

		for _, pull in fetched.pulls do
			record(pull)
		end

		for _, pull in fetched.authored or {} do
			record(pull)
		end

		healRefKeys(current)

		return report
	end
end

return refresh
