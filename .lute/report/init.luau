--[[
	Publishes CI results. Each subcommand runs from a workflow step, and its
	module explains what it reads and where it posts.

	lute run report coverage
		Posts the app's test coverage from CI's app job.

	lute run report perf
		Posts the perf comparison from CI's perf job or the Perf Report
		workflow.

	lute run report perf-history
		Records CI's perf run in PostHog.

	lute run report storybook
		Links a pull request to the Storybook Chromatic published for it.
]]
local process = require("@std/process")

local runScript = require("@workspace/orion-cli/src/common/process/runScript")

local commentStorybook = require("@self/storybook")
local recordPerfHistory = require("@self/perfHistory")
local reportCoverage = require("@self/coverage")
local reportPerf = require("@self/perf")

local REPORTS: { [string]: () -> () } = {
	coverage = reportCoverage,
	perf = reportPerf,
	["perf-history"] = recordPerfHistory,
	storybook = commentStorybook,
}

runScript(function()
	local name = process.args[2]
	local report = REPORTS[name or ""]
	assert(report, `unknown report {name}; try coverage, perf, perf-history, or storybook`)
	report()
end)
