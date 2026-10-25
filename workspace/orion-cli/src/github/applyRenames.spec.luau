local json = require("@std/json")
local test = require("@std/test")

local applyRenames = require("@root/github/applyRenames")
local getRefs = require("@root/refs/getRefs")
local testing = require("@root/testing")

local RENAMES = { ["vocksel/orion"] = "gummy-galaxy/orion" }

local function card(id: string, refs: { json.Object }, repo: string?): any
	return testing.task(id, id, "active", nil, json.object({ refs = refs, repo = repo }))
end

local function ref(kind: string, key: string, url: string?): json.Object
	return json.object({ source = "github", kind = kind, key = key, url = url, status = "open" })
end

test.case("pull request, issue, and branch refs take the new name and keep the rest", function(assert)
	local doc = testing.createDoc({
		card("a", {
			ref("pull", "vocksel/orion#12", "https://github.com/vocksel/orion/pull/12"),
			ref("branch", "vocksel/orion@agent/fix"),
		}, "vocksel/orion"),
		card("b", { ref("issue", "Vocksel/Orion#3", "https://github.com/Vocksel/Orion/issues/3?x=1") }),
	})

	local moves = applyRenames(doc, RENAMES)

	local first = getRefs(doc.nodes[1])
	assert.eq(first[1].key, "gummy-galaxy/orion#12")
	assert.eq(first[1].url, "https://github.com/gummy-galaxy/orion/pull/12")
	assert.eq(first[1].status, "open")
	assert.eq(first[2].key, "gummy-galaxy/orion@agent/fix")
	assert.eq(doc.nodes[1].data.repo, "gummy-galaxy/orion")

	local second = getRefs(doc.nodes[2])
	assert.eq(second[1].key, "gummy-galaxy/orion#3")
	assert.eq(second[1].url, "https://github.com/gummy-galaxy/orion/issues/3?x=1")

	assert.eq(#moves, 1)
	assert.eq(moves[1].from, "vocksel/orion")
	assert.eq(moves[1].to, "gummy-galaxy/orion")
end)

test.case("refs in other repositories and other sources stay as they are", function(assert)
	local doc = testing.createDoc({
		card("a", {
			ref("pull", "vocksel/orion-docs#1"),
			ref("pull", "flipbook-labs/flipbook#2", "https://github.com/flipbook-labs/flipbook/pull/2"),
			json.object({ source = "jira", kind = "issue", key = "ABC-1" }),
		}, "flipbook-labs/flipbook"),
	})

	local moves = applyRenames(doc, RENAMES)

	local refs = getRefs(doc.nodes[1])
	assert.eq(refs[1].key, "vocksel/orion-docs#1")
	assert.eq(refs[2].url, "https://github.com/flipbook-labs/flipbook/pull/2")
	assert.eq(refs[3].key, "ABC-1")
	assert.eq(doc.nodes[1].data.repo, "flipbook-labs/flipbook")
	assert.eq(#moves, 0)
end)

test.case("a card that already has the ref under its new name drops the old one", function(assert)
	local doc = testing.createDoc({
		card("a", { ref("pull", "vocksel/orion#12"), ref("pull", "gummy-galaxy/orion#12") }),
	})

	applyRenames(doc, RENAMES)

	local refs = getRefs(doc.nodes[1])
	assert.eq(#refs, 1)
	assert.eq(refs[1].key, "gummy-galaxy/orion#12")
end)

test.case("Enterprise refs keep their host in front", function(assert)
	local doc = testing.createDoc({
		card("a", { ref("pull", "ghe.example.com/team/app#4", "https://ghe.example.com/team/app/pull/4") }, "team/app"),
	})

	applyRenames(doc, { ["ghe.example.com/team/app"] = "platform/app" })

	local refs = getRefs(doc.nodes[1])
	assert.eq(refs[1].key, "ghe.example.com/platform/app#4")
	assert.eq(refs[1].url, "https://ghe.example.com/platform/app/pull/4")
	assert.eq(doc.nodes[1].data.repo, "platform/app")
end)

test.case("a card with only a repository takes the new name", function(assert)
	local doc = testing.createDoc({ card("a", {}, "vocksel/orion") })

	local moves = applyRenames(doc, RENAMES)

	assert.eq(doc.nodes[1].data.repo, "gummy-galaxy/orion")
	assert.eq(#moves, 1)
end)

test.case("CI snoozes move with their repository, and a snooze already there wins", function(assert)
	local doc = testing.createDoc({})
	local snoozes = doc.settings.checkSnoozes
	table.insert(snoozes, { repo = "vocksel/orion", name = "lint", at = "old", passed = {} })
	table.insert(snoozes, { repo = "vocksel/orion", name = "docs", at = "old", passed = { "a" } })
	table.insert(snoozes, { repo = "gummy-galaxy/orion", name = "lint", at = "new", passed = {} })

	applyRenames(doc, RENAMES)

	assert.eq(#snoozes, 2)
	assert.eq(snoozes[1].name, "docs")
	assert.eq(snoozes[1].repo, "gummy-galaxy/orion")
	assert.eq(snoozes[1].passed[1], "a")
	assert.eq(snoozes[2].at, "new")
end)

test.case("no renames changes nothing", function(assert)
	local doc = testing.createDoc({ card("a", { ref("pull", "vocksel/orion#12") }, "vocksel/orion") })

	assert.eq(#applyRenames(doc, {}), 0)
	assert.eq(getRefs(doc.nodes[1])[1].key, "vocksel/orion#12")
end)
