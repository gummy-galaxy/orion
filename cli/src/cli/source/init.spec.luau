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
		"--owners",
		" Roblox, Example, , ",
		"--include",
		" avatar, hop, , ",
		"--exclude",
		" old, archived, , ",
	})
	run({ "source", "add", "jira", "--command", [[ ["acli","jira","workitem","search","--json"] ]] })
	run({ "source", "add", "hop" })
	local values = json.asArray(json.deserialize(run({ "source", "list", "--json" })) :: json.Value)
	assert.eq(values and #values, 3)
	local github = store.load(dir).settings.sources[1]
	assert.eq(github.owners, { "Roblox", "Example" })
	assert.eq(github.include, { "avatar", "hop" })
	assert.eq(github.exclude, { "old", "archived" })
	assert.throws(function()
		run({ "source", "add", "github", "--host", "evil/@host", "--owners", "Roblox" })
	end)
	assert.throws(function()
		run({ "source", "add", "github", "--host", "github.com", "--owners", " , , " })
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
	assert.strContains(run({ "source", "add", "--help" }), "--owners")
	assert.strContains(run({ "source", "add", "--help" }), "GitHub owners, comma-separated")
	run({ "source", "add", "--workspace", "beta", "hop", "--id", "hop-beta-two" })
	setWorkspace("beta")
	assert.strContains(run({ "source", "list" }), "hop-beta")
	assert.eq(#store.load(store.getWorkspaceDir(root, "beta")).settings.sources, 2)
end)
