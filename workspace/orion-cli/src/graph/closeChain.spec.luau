local test = require("@std/test")

local closeChain = require("@root/graph/closeChain")
local getItem = require("@root/graph/getItem")
local getRecordedStatuses = require("@root/graph/getRecordedStatuses")
local markCelebrations = require("@root/graph/markCelebrations")
local testing = require("@root/testing")

local task = testing.task

test.case("closeChain closes out a waiting chain both ways and reports each card's hops", function(assert)
	local doc = testing.createDoc({
		task("a", "A", "done", nil, { celebrate = true }),
		task("b", "B", "done", nil, { celebrate = true }),
		task("c", "C", "done"),
		task("d", "D", "done", nil, { celebrate = true }),
		task("up", "Up", "done", nil, { celebrate = true }),
		task("open", "Open", "active", nil, { celebrate = true }),
		task("beyond", "Beyond", "done", nil, { celebrate = true }),
	}, { { "a", "b" }, { "b", "c" }, { "c", "d" }, { "up", "a" }, { "d", "open" }, { "open", "beyond" } })

	local result = closeChain(doc, "a")

	assert.eq(result.closed, {
		{ id = "a", hops = 0 },
		{ id = "b", hops = 1 },
		{ id = "up", hops = 1 },
		{ id = "d", hops = 3 },
	})
	assert.eq(result.passed, { { id = "c", hops = 2 } })

	for _, id in { "a", "b", "up", "d" } do
		assert.eq(getItem(doc, id).data.celebrate, false)
	end

	assert.eq(getItem(doc, "c").data.celebrate, nil)
	assert.eq(getItem(doc, "beyond").data.celebrate, true)
end)

test.case("closeChain stops at related links and passes through finished notes", function(assert)
	local doc = testing.createDoc({
		task("a", "A", "done", nil, { celebrate = true }),
		task("n", "Note", "todo", nil, { type = "note" }),
		task("b", "B", "done", nil, { celebrate = true }),
		task("r", "Related", "done", nil, { celebrate = true }),
	}, { { "a", "n" }, { "n", "b" }, { "a", "r", "related" } })

	local result = closeChain(doc, "a")

	assert.eq(result.closed, { { id = "a", hops = 0 }, { id = "b", hops = 2 } })
	assert.eq(result.passed, { { id = "n", hops = 1 } })
	assert.eq(getItem(doc, "r").data.celebrate, true)
end)

test.case("closeChain closes out a done card that isn't waiting, and one finished in the same write", function(assert)
	local doc = testing.createDoc({
		task("a", "A", "done"),
		task("b", "B", "active"),
		task("c", "C", "done", nil, { celebrate = true }),
	}, { { "a", "b" }, { "b", "c" } })

	assert.eq(closeChain(doc, "a").closed, { { id = "a", hops = 0 } })

	local previous = getRecordedStatuses(doc)
	getItem(doc, "b").data.status = "done"
	local result = closeChain(doc, "b")
	markCelebrations(doc, previous)

	assert.eq(result.closed, { { id = "b", hops = 0 }, { id = "c", hops = 1 } })
	assert.eq(result.passed, { { id = "a", hops = 1 } })
	assert.eq(getItem(doc, "b").data.celebrate, nil)
	assert.eq(getItem(doc, "c").data.celebrate, nil)
end)

test.case("closeChain refuses open work, notes, and groups", function(assert)
	local doc = testing.createDoc({
		task("open", "Open", "active"),
		task("n", "Note", "todo", nil, { type = "note" }),
		testing.group("g", "Group"),
	})

	assert.throwsWith(`"open" isn't done yet; finish it before closing it out`, function()
		closeChain(doc, "open")
	end)
	assert.throwsWith(`"n" isn't a work item, so it has nothing to close out`, function()
		closeChain(doc, "n")
	end)
	assert.throwsWith(`"g" isn't a work item, so it has nothing to close out`, function()
		closeChain(doc, "g")
	end)
	assert.throwsWith(`no item or group with id "missing"`, function()
		closeChain(doc, "missing")
	end)
end)
