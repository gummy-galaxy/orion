local adapterTypes = require("@root/sources/types")
local claudeCreateSource = require("@root/sources/claude/createSource")
local claudeGetWatchPaths = require("@root/sources/claude/getWatchPaths")
local claudeListSessionsAsync = require("@root/sources/claude/listSessionsAsync")
local claudeReadTurnsAsync = require("@root/sources/claude/readTurnsAsync")
local githubCollectAsync = require("@root/sources/github/collectAsync")
local githubCreateSource = require("@root/sources/github/createSource")
local githubLookupRefsAsync = require("@root/sources/github/lookupRefsAsync")
local githubRefFromUrl = require("@root/sources/github/refFromUrl")
local githubRefreshAsync = require("@root/sources/github/refreshAsync")
local githubRefreshChangedAsync = require("@root/sources/github/refreshChangedAsync")
local hopCollectAsync = require("@root/sources/hop/collectAsync")
local hopCreateSource = require("@root/sources/hop/createSource")
local jiraCollectAsync = require("@root/sources/jira/collectAsync")
local jiraCreateSource = require("@root/sources/jira/createSource")
local jiraLookupRefsAsync = require("@root/sources/jira/lookupRefsAsync")
local jiraRefFromKey = require("@root/sources/jira/refFromKey")
local jiraRefFromUrl = require("@root/sources/jira/refFromUrl")

type Adapter = adapterTypes.Adapter

local adapters: { [string]: Adapter } = {
	claude = {
		kind = "claude",
		createSource = claudeCreateSource,
		agent = {
			name = "Claude Code",
			listSessionsAsync = claudeListSessionsAsync,
			readTurnsAsync = claudeReadTurnsAsync,
			watchPaths = claudeGetWatchPaths,
		},
	},
	github = {
		kind = "github",
		createSource = githubCreateSource,
		source = {
			collectAsync = githubCollectAsync,
			refreshAsync = githubRefreshAsync,
			refreshChangedAsync = githubRefreshChangedAsync,
			refFromUrl = githubRefFromUrl,
			lookupRefsAsync = githubLookupRefsAsync,
		},
	},
	jira = {
		kind = "jira",
		createSource = jiraCreateSource,
		source = {
			collectAsync = jiraCollectAsync,
			refFromUrl = jiraRefFromUrl,
			refFromKey = jiraRefFromKey,
			lookupRefsAsync = jiraLookupRefsAsync,
		},
	},
	hop = {
		kind = "hop",
		createSource = hopCreateSource,
		source = { collectAsync = hopCollectAsync, collectOrder = 1 },
	},
}

local function getAdapter(kind: string): Adapter
	return assert(adapters[kind], `unknown source kind {kind}`)
end

return getAdapter
