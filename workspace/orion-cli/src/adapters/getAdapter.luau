local adapterTypes = require("@root/adapters/types")
local githubCollectAsync = require("@root/adapters/github/collectAsync")
local githubCreateSource = require("@root/adapters/github/createSource")
local githubLookupRefsAsync = require("@root/adapters/github/lookupRefsAsync")
local githubRefFromUrl = require("@root/adapters/github/refFromUrl")
local githubRefreshAsync = require("@root/adapters/github/refreshAsync")
local githubRefreshChangedAsync = require("@root/adapters/github/refreshChangedAsync")
local hopCollectAsync = require("@root/adapters/hop/collectAsync")
local hopCreateSource = require("@root/adapters/hop/createSource")
local jiraCollectAsync = require("@root/adapters/jira/collectAsync")
local jiraCreateSource = require("@root/adapters/jira/createSource")
local jiraLookupRefsAsync = require("@root/adapters/jira/lookupRefsAsync")
local jiraRefFromKey = require("@root/adapters/jira/refFromKey")
local jiraRefFromUrl = require("@root/adapters/jira/refFromUrl")

type Adapter = adapterTypes.Adapter

local adapters: { [string]: Adapter } = {
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
