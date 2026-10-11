-- Identifies the perf comment CI keeps on a pull request, and the line it shows when the comparison fails.
local perfComment = {
	MARKER = "<!-- orion-perf -->",
	FAILURE = "The perf comparison failed. See the run for details.",
}

return perfComment
