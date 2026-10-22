local json = require("@std/json")
local test = require("@std/test")

local getItem = require("@root/graph/getItem")
local loadDoc = require("@root/store/loadDoc")
local testing = require("@root/testing")
local writeDoc = require("@root/store/writeDoc")

local task = testing.task

local function createChain(name: string): string
	local dir = testing.directory(name)
	writeDoc(
		dir,
		testing.createDoc({
			task("a", "Ship the parser", "done", nil, { celebrate = true }),
			task("b", "Ship the docs", "done"),
			task("c", "Ship the release", "done", nil, { celebrate = true }),
			task("open", "Announce it", "active"),
		}, { { "a", "b" }, { "b", "c" }, { "c", "open" } })
	)
	return dir
end

test.case("card close-out closes out a waiting chain and names each card closed", function(assert)
	local dir = createChain("close-out-chain")
	local text = testing.run(dir, { "card", "close-out", "a" })
	assert.strContains(text, "Closed out 2 cards at revision 0 → 1")
	assert.strContains(text, "a · Ship the parser")
	assert.strContains(text, "c · Ship the release")
	assert.strNotContains(text, "b · Ship the docs")
	local doc = loadDoc(dir)
	assert.eq(getItem(doc, "a").data.celebrate, nil)
	assert.eq(getItem(doc, "c").data.celebrate, nil)
end)

test.case("card close-out prints the chain with hops as JSON, and previews without writing", function(assert)
	local dir = createChain("close-out-json")
	local preview = testing.run(dir, { "card", "close-out", "c", "--dry-run" })
	assert.strContains(preview, "Would close out 2 cards at revision 0")
	assert.eq(getItem(loadDoc(dir), "a").data.celebrate, true)

	local report = json.asObject(
		json.deserialize(testing.run(dir, { "card", "close-out", "c", "--json" })) :: json.Value
	) :: json.Object
	assert.eq(report.revision, 1)
	local closed = json.asArray(report.closed) :: json.Array
	local passed = json.asArray(report.passed) :: json.Array
	assert.eq(#closed, 2)
	assert.eq((json.asObject(closed[1]) :: json.Object).id, "c")
	assert.eq((json.asObject(closed[2]) :: json.Object).hops, 2)
	assert.eq((json.asObject(passed[1]) :: json.Object).id, "b")
	assert.eq((json.asObject(passed[1]) :: json.Object).hops, 1)
end)

test.case("card close-out refuses open work, groups, and stale revisions", function(assert)
	local dir, run = testing.createHarness("close-out-refuse")
	assert.throwsWith(`"ci" isn't done yet; finish it before closing it out`, function()
		run({ "card", "close-out", "ci" })
	end)
	assert.throwsWith(`"ws" is a group; use orion group set`, function()
		run({ "card", "close-out", "ws" })
	end)
	assert.throwsWith("revision changed: expected 4, current 0", function()
		run({ "card", "close-out", "ci", "--if-revision", "4" })
	end)
	assert.eq(loadDoc(dir).revision, 0)
end)
