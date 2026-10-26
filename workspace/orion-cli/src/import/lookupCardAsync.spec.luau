local json = require("@std/json")
local test = require("@std/test")

local lookupCardAsync = require("@root/import/lookupCardAsync")
local testing = require("@root/testing")
local types = require("@root/types")

local NOW = "2026-10-12T00:00:00Z"
local PULL_URL = "https://github.com/Roblox/foundation/pull/2376"

local function githubRunner(): types.CommandResult
	return testing.result(
		true,
		`\{"data": \{"p1": \{"pullRequest": \{"title": "Add a Chip component", "url": "{PULL_URL}"}}}}`
	)
end

local function unreachableRunner(): types.CommandResult
	error("no lookup should run")
end

test.case("a pull request URL finds a new card without adding it", function(assert)
	local doc = testing.createDoc({ testing.task("other", "Other work", "todo") })

	local found = lookupCardAsync(PULL_URL, doc, {}, NOW, githubRunner)

	assert.eq(found.status, "found")
	assert.eq(found.item.data.label, "Add a Chip component")
	assert.eq(found.item.data.repo, "Roblox/foundation")
	assert.eq(found.item.data.itemKind, "pr")
	local refs = found.item.data.refs :: { json.Object }
	assert.eq(refs[1].kind, "pull")
	assert.eq(refs[1].key, "Roblox/foundation#2376")
	assert.eq(#doc.nodes, 1)
end)

test.case("a URL a card already tracks returns that card without a lookup", function(assert)
	local doc = testing.createDoc({
		testing.task("kept", "Already tracked", "todo", nil, {
			refs = { { source = "github", kind = "pull", key = "Roblox/foundation#2376", url = PULL_URL } },
		}),
	})

	local found = lookupCardAsync(PULL_URL, doc, {}, NOW, unreachableRunner)

	assert.eq(found.status, "existing")
	assert.eq(found.item.id, "kept")
end)

test.case("a URL no source recognizes raises the reason", function(assert)
	local succeeded, failure =
		pcall(lookupCardAsync, "https://example.com/page", testing.createDoc({}), {}, NOW, unreachableRunner)

	assert.eq(succeeded, false)
	assert.strContains(tostring(failure), "no source recognizes https://example.com/page")
end)

test.case("a pull request GitHub can't find raises the reason", function(assert)
	local succeeded, failure = pcall(lookupCardAsync, PULL_URL, testing.createDoc({}), {}, NOW, function()
		return testing.result(true, '{"data": {"p1": {"pullRequest": null}}}')
	end)

	assert.eq(succeeded, false)
	assert.strContains(tostring(failure), "not found on github.com")
end)

return {}
