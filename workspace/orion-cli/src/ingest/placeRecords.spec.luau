local json = require("@std/json")
local test = require("@std/test")

local adapterTypes = require("@root/adapters/types")
local findRef = require("@root/refs/findRef")
local ingestTypes = require("@root/ingest/types")
local placeRecords = require("@root/ingest/placeRecords")
local testing = require("@root/testing")
local types = require("@root/types")

type Record = adapterTypes.Record
type Result = ingestTypes.Result
type Source = types.Source

local SOURCE: Source = { id = "example", kind = "example" }

local function result(records: { Record }): Result
	return { source = SOURCE, report = { id = SOURCE.id, added = 0, updated = 0, linked = 0 }, records = records }
end

test.case("placeRecords creates in Unsorted and updates by ref", function(assert)
	local doc = testing.createDoc({})
	local record: Record = {
		ref = { source = "example", kind = "issue", key = "ABC-1" },
		label = "First",
		repo = "owner/repo",
		status = "active",
		who = "you",
	}
	local first = placeRecords(doc, { result({ record }) })
	assert.eq(first.sources[1].added, 1)
	assert.eq(doc.nodes[1].id, "unsorted")
	assert.eq(doc.nodes[1].data.layout, "refit")
	assert.eq(doc.nodes[2].data.status, "active")
	assert.eq(doc.nodes[2].data.repo, "owner/repo")

	record.label = "Revised"
	record.status = "done"
	record.who = nil
	local second = placeRecords(doc, { result({ record }) })
	assert.eq(second.sources[1].updated, 1)
	assert.eq(#doc.nodes, 2)
	assert.eq(doc.nodes[2].data.label, "Revised")
	assert.eq(doc.nodes[2].data.who, nil)
	assert.eq(findRef(doc.nodes[2], "issue", "abc-1") ~= nil, true)
end)

test.case("placeRecords uses fallback, skips missing update-only, and computes status", function(assert)
	local existing = testing.task("branch", "Branch", "blocked", nil, { repo = "owner/repo" })
	local doc = testing.createDoc({ existing })
	local skipped = result({
		{
			ref = { source = "example", kind = "branch", key = "owner/repo@missing" },
			label = "Missing",
			isUpdateOnly = true,
		},
	})
	placeRecords(doc, { skipped })
	assert.eq(#doc.nodes, 1)
	assert.eq(skipped.report.updated, 0)

	local adopted = result({
		{
			ref = { source = "example", kind = "pull", key = "owner/repo#2" },
			label = "Pull",
			findFallback = function()
				return existing
			end,
			updateStatus = function(item)
				assert.eq(item.data.status, "blocked")
				assert.eq(item.data.who, nil)
				item.data.status, item.data.who = "review", "review"
			end,
		},
	})
	placeRecords(doc, { adopted })
	assert.eq(adopted.report.updated, 1)
	assert.eq(#doc.nodes, 1)
	assert.eq(existing.data.status, "review")
	assert.eq(existing.data.who, "review")
	assert.eq(testing.primaryType(existing), "pr")
end)

test.case("placeRecords updates the card whose ref has the record's id, under the record's new key", function(assert)
	local doc = testing.createDoc({})
	local record: Record = {
		ref = { source = "example", kind = "pull", key = "vocksel/orion#12", id = "R_1#12" },
		label = "Fix",
	}
	placeRecords(doc, { result({ record }) })

	record.ref = { source = "example", kind = "pull", key = "gummy-galaxy/orion#12", id = "R_1#12" }
	local second = placeRecords(doc, { result({ record }) })

	assert.eq(second.sources[1].added, 0)
	assert.eq(second.sources[1].updated, 1)
	assert.eq(#doc.nodes, 2)
	assert.eq(findRef(doc.nodes[2], "pull", "gummy-galaxy/orion#12") ~= nil, true)
	assert.eq(findRef(doc.nodes[2], "pull", "vocksel/orion#12"), nil)
end)

test.case("placeRecords matches a record that names a moved repository's old name", function(assert)
	local doc = testing.createDoc({
		testing.task("moved", "Moved", "active", nil, {
			repo = "gummy-galaxy/orion",
			refs = {
				{ source = "hop", kind = "branch", key = "gummy-galaxy/orion@agent/fix", id = "1@agent/fix" },
			},
		}),
	})
	doc.repositories = json.object({
		["1"] = json.object({ name = "gummy-galaxy/orion", aliases = { "vocksel/orion" } }),
	})
	local record: Record = {
		ref = { source = "hop", kind = "branch", key = "vocksel/orion@agent/fix" },
		label = "agent fix",
		repo = "vocksel/orion",
	}

	local report = placeRecords(doc, { result({ record }) })

	assert.eq(report.sources[1].added, 0)
	assert.eq(report.sources[1].updated, 1)
	assert.eq(#doc.nodes, 1)
	assert.eq(doc.nodes[1].data.repo, "gummy-galaxy/orion")
end)
