local applyPulls = require("@root/github/applyPulls")
local collectChangedAsync = require("@root/github/collectChangedAsync")
local githubTypes = require("@root/github/types")
local types = require("@root/types")

type ChangedRefresh = githubTypes.ChangedRefresh
type PollState = githubTypes.PollState
type Want = githubTypes.Want
type Doc = types.Doc
type CommandRunner = types.CommandRunner

-- Like `refreshAsync`, but fetches only the cards that changed and returns no apply step when nothing did.
local function refreshChangedAsync(
	doc: Doc,
	run: CommandRunner,
	poll: PollState,
	want: Want,
	now: string
): ChangedRefresh
	local changes = collectChangedAsync(doc, run, poll, want)
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

return refreshChangedAsync
