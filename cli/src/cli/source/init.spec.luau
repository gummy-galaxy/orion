local json = require("@std/json")
local test = require("@std/test")

local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local loadDoc = require("@root/store/loadDoc")
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
	local github = loadDoc(dir).settings.sources[1]
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
	assert.eq(#loadDoc(dir).settings.sources, 2)
end)

test.case("sources stay in their selected workspace", function(assert)
	local root, run, setWorkspace = testing.createHarness("source-workspaces")
	run({ "canvas", "create", "alpha" })
	run({ "canvas", "create", "beta" })
	run({ "source", "add", "hop", "--canvas", "alpha", "--id", "hop-alpha" })
	run({ "--canvas", "beta", "source", "add", "hop", "--id", "hop-beta" })
	local alpha = loadDoc(getWorkspaceDir(root, "alpha"))
	local beta = loadDoc(getWorkspaceDir(root, "beta"))
	assert.eq(alpha.settings.sources[1].id, "hop-alpha")
	assert.eq(beta.settings.sources[1].id, "hop-beta")
	assert.eq(#loadDoc(root).settings.sources, 0)
	assert.strContains(run({ "source", "list", "--canvas", "alpha" }), "hop-alpha")
	assert.strContains(run({ "source", "add", "--help" }), "github - Add a GitHub source")
	assert.strContains(run({ "source", "add", "github", "--help" }), "GitHub owners, comma-separated")
	assert.strContains(run({ "source", "add", "hop", "-h" }), "Add a hop source")
	run({ "source", "add", "--canvas", "beta", "hop", "--id", "hop-beta-two" })
	setWorkspace("beta")
	assert.strContains(run({ "source", "list" }), "hop-beta")
	assert.eq(#loadDoc(getWorkspaceDir(root, "beta")).settings.sources, 2)
end)

test.case("source add takes only the options that apply to its kind", function(assert)
	local dir, run = testing.createHarness("source-kind-options")
	assert.throwsWith("Unknown argument: owners", function()
		run({ "source", "add", "jira", "--owners", "Roblox", "--command", [[ ["acli","jira","workitem","search"] ]] })
	end)
	assert.throwsWith("Unknown argument: browse", function()
		run({ "source", "add", "hop", "--browse", "https://jira.example.com/browse" })
	end)
	assert.throwsWith("Unknown argument: host", function()
		run({ "source", "add", "hop", "--host", "github.com" })
	end)
	assert.eq(#loadDoc(dir).settings.sources, 0)
	assert.throwsWith("choose github, jira, or hop", function()
		run({ "source", "add" })
	end)
end)
