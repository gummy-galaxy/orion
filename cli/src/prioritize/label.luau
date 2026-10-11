-- The label the Beelink supervisor reads to run a pull request's queued jobs ahead of other work.
local label = {
	NAME = "priority-queue",
	COLOR = "5319E7",
	DESCRIPTION = "Run this pull request's queued CI jobs ahead of other work",
}

return label
