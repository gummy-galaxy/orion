local applyPulls = require("@root/github/applyPulls")
local collectChanged = require("@root/github/collectChanged")
local githubTypes = require("@root/github/types")
local types = require("@root/types")

type ChangedRefresh = githubTypes.ChangedRefresh
type PollState = githubTypes.PollState
type Want = githubTypes.Want
type Doc = types.Doc
type CommandRunner = types.CommandRunner

-- Like `refresh`, but fetches only the cards that changed and returns no apply step when nothing did.
local function refreshChanged(doc: Doc, run: CommandRunner, poll: PollState, want: Want, now: string): ChangedRefresh
	local changes = collectChanged(doc, run, poll, want)
	local fetched = changes.fetched

	return {
		apply = if fetched
			then function(current: Doc): githubTypes.Report
				return applyPulls(current, fetched, now)
			end
			else nil,
		failures = changes.failures,
		fetched = changes.refetched,
	}
end

return refreshChanged
