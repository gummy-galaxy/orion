local json = require("@std/json")
local test = require("@std/test")

local store = require("@root/store")
local testing = require("@root/testing")

test.case("source commands validate and persist configuration", function(assert)
	local dir, run = testing.createHarness("sources")
	run({
		"source",
		"add",
		"github",
		"--host",
		"github.com",
		"--owner",
		"Roblox",
		"--owner",
		"Example",
		"--include",
		"avatar",
	})
	run({ "source", "add", "jira", "--command", [[ ["acli","jira","workitem","search","--json"] ]] })
	run({ "source", "add", "hop" })
	local values = json.asArray(json.deserialize(run({ "source", "list", "--json" })) :: json.Value)
	assert.eq(values and #values, 3)
	assert.eq(store.load(dir).settings.sources[1].owners, { "Roblox", "Example" })
	assert.throws(function()
		run({ "source", "add", "github", "--host", "evil/@host", "--owner", "Roblox" })
	end)
	run({ "source", "remove", "hop" })
	assert.eq(#store.load(dir).settings.sources, 2)
end)

test.case("sources stay in their selected workspace", function(assert)
	local root, run, setWorkspace = testing.createHarness("source-workspaces")
	run({ "workspace", "create", "alpha" })
	run({ "workspace", "create", "beta" })
	run({ "source", "add", "hop", "--workspace", "alpha", "--id", "hop-alpha" })
	run({ "--workspace", "beta", "source", "add", "hop", "--id", "hop-beta" })
	local alpha = store.load(store.getWorkspaceDir(root, "alpha"))
	local beta = store.load(store.getWorkspaceDir(root, "beta"))
	assert.eq(alpha.settings.sources[1].id, "hop-alpha")
	assert.eq(beta.settings.sources[1].id, "hop-beta")
	assert.eq(#store.load(root).settings.sources, 0)
	assert.strContains(run({ "source", "list", "--workspace", "alpha" }), "hop-alpha")
	assert.strContains(run({ "source", "add", "--help" }), "--owner")
	run({ "source", "add", "--workspace", "beta", "hop", "--id", "hop-beta-two" })
	setWorkspace("beta")
	assert.strContains(run({ "source", "list" }), "hop-beta")
	assert.eq(#store.load(store.getWorkspaceDir(root, "beta")).settings.sources, 2)
end)
