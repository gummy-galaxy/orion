local json = require("@std/json")
local test = require("@std/test")

local store = require("@root/store")
local testing = require("@root/testing")

local NOW = "2026-10-04T00:00:00Z"

test.case("ingest dry run reports changes without writing", function(assert)
	local dir = testing.directory("ingest-dry-run")
	local doc = testing.createDoc({})
	doc.settings.sources = { { id = "jira", kind = "jira", command = { "acli", "jira", "workitem", "search" } } }
	store.write(dir, doc)

	local function run(args: { string }): string
		return testing.run(dir, args, function()
			return testing.result(true, [[ [{"key":"ABC-9","summary":"Ship","statusCategory":"new","type":"Task"}] ]])
		end, NOW)
	end

	local report = json.asObject(json.deserialize(run({ "ingest", "--dry-run", "--json" })) :: json.Value)
	local sources = if report then json.asArray(report.sources) else nil
	local first = if sources then json.asObject(sources[1]) else nil
	assert.eq(first and first.added, 1)
	assert.eq(store.load(dir).revision, 0)
	run({ "ingest" })
	assert.eq(store.load(dir).revision, 1)
	assert.eq(#store.load(dir).nodes, 2)
end)
