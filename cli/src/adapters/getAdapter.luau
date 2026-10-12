local adapterTypes = require("@root/adapters/types")
local githubCollect = require("@root/adapters/github/collect")
local githubCreateSource = require("@root/adapters/github/createSource")
local githubLookupRefs = require("@root/adapters/github/lookupRefs")
local githubRefFromUrl = require("@root/adapters/github/refFromUrl")
local githubRefresh = require("@root/adapters/github/refresh")
local hopCollect = require("@root/adapters/hop/collect")
local hopCreateSource = require("@root/adapters/hop/createSource")
local jiraCollect = require("@root/adapters/jira/collect")
local jiraCreateSource = require("@root/adapters/jira/createSource")
local jiraLookupRefs = require("@root/adapters/jira/lookupRefs")
local jiraRefFromKey = require("@root/adapters/jira/refFromKey")
local jiraRefFromUrl = require("@root/adapters/jira/refFromUrl")

type Adapter = adapterTypes.Adapter

local adapters: { [string]: Adapter } = {
	github = {
		kind = "github",
		createSource = githubCreateSource,
		collect = githubCollect,
		refresh = githubRefresh,
		refFromUrl = githubRefFromUrl,
		lookupRefs = githubLookupRefs,
	},
	jira = {
		kind = "jira",
		createSource = jiraCreateSource,
		collect = jiraCollect,
		refFromUrl = jiraRefFromUrl,
		refFromKey = jiraRefFromKey,
		lookupRefs = jiraLookupRefs,
	},
	hop = { kind = "hop", createSource = hopCreateSource, collect = hopCollect, collectOrder = 1 },
}

local function getAdapter(kind: string): Adapter
	return assert(adapters[kind], `unknown source kind {kind}`)
end

return getAdapter
