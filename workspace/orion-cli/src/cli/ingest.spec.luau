local json = require("@std/json")
local test = require("@std/test")

local loadDoc = require("@root/store/loadDoc")
local setSourceCommand = require("@root/sources/setSourceCommand")
local testing = require("@root/testing")
local writeDoc = require("@root/store/writeDoc")

local NOW = "2026-10-04T00:00:00Z"

test.case("ingest dry run reports changes without writing", function(assert)
	local dir = testing.directory("ingest-dry-run")
	local doc = testing.createDoc({})
	doc.settings.sources = { { id = "jira", kind = "jira" } }
	writeDoc(dir, doc)
	setSourceCommand(dir, "default", "jira", { "acli", "jira", "workitem", "search" })

	local function run(args: { string }): string
		return testing.run(dir, args, function()
			return testing.result(true, [[ [{"key":"ABC-9","summary":"Ship","statusCategory":"new","type":"Task"}] ]])
		end, NOW)
	end

	local report = json.asObject(json.deserialize(run({ "ingest", "--dry-run", "--json" })) :: json.Value)
	local sources = if report then json.asArray(report.sources) else nil
	local first = if sources then json.asObject(sources[1]) else nil
	assert.eq(first and first.added, 1)
	assert.eq(loadDoc(dir).revision, 0)
	run({ "ingest" })
	assert.eq(loadDoc(dir).revision, 1)
	assert.eq(#loadDoc(dir).nodes, 2)
end)

test.case("ingest keeps a card whose repository moved, under its new name", function(assert)
	local dir = testing.directory("ingest-moved-repository")
	local doc = testing.createDoc({
		testing.task(
			"tracked",
			"Tracked",
			"active",
			nil,
			json.object({
				repo = "vocksel/orion",
				refs = {
					json.object({
						source = "github",
						kind = "pull",
						key = "vocksel/orion#12",
						url = "https://github.com/vocksel/orion/pull/12",
						status = "merged",
					}),
				},
			})
		),
	})
	doc.settings.sources = { { id = "github", kind = "github", host = "github.com", owners = { "gummy-galaxy" } } }
	writeDoc(dir, doc)

	local function runner(argv: { string })
		local query = argv[#argv]

		if query:find("r1: repository(", 1, true) then
			return testing.result(true, '{"data":{"r1":{"databaseId":1,"nameWithOwner":"gummy-galaxy/orion"}}}')
		elseif query:find("viewer { login }", 1, true) then
			return testing.result(true, '{"data":{"viewer":{"login":"me"}}}')
		elseif query:find("is:open is:pr", 1, true) then
			return testing.result(
				true,
				'{"data":{"search":{"nodes":[{"number":12,"title":"Fix","url":"https://github.com/gummy-galaxy/orion/pull/12","state":"OPEN","headRefName":"fix","author":{"login":"me"},"repository":{"databaseId":1,"nameWithOwner":"gummy-galaxy/orion","name":"orion","owner":{"login":"gummy-galaxy"}}}],"pageInfo":{"hasNextPage":false}}}}'
			)
		end

		return testing.result(true, '{"data":{"search":{"nodes":[],"pageInfo":{"hasNextPage":false}}}}')
	end

	testing.run(dir, { "ingest" }, runner, NOW)

	local loaded = loadDoc(dir)
	assert.eq(#loaded.nodes, 1)
	assert.eq(loaded.nodes[1].data.repo, "gummy-galaxy/orion")
	local refs = json.asArray(loaded.nodes[1].data.refs) or {}
	assert.eq(#refs, 1)
	local first = json.asObject(refs[1])
	assert.eq(if first then first.key else nil, "gummy-galaxy/orion#12")
	assert.eq(if first then first.id else nil, "1#12")
	assert.eq(if first then first.url else nil, "https://github.com/gummy-galaxy/orion/pull/12")
	local repositories = loaded.repositories
	local entry = if repositories then json.asObject(repositories["1"]) else nil
	assert.eq(if entry then entry.name else nil, "gummy-galaxy/orion")
end)
