local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@lute/net/server")
local test = require("@std/test")

local createWorkspace = require("@root/storage/canvases/createWorkspace")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local sessionStart = require("@root/server/routes/sessionStart")
local testing = require("@root/testing")
local writeDoc = require("@root/storage/canvases/writeDoc")

local function request(method: string, query: { [string]: string }, body: json.Object?): net.ReceivedRequest
	return {
		method = method,
		path = "/api/sessions/start",
		body = if body then json.serialize(body) else "",
		query = query,
		headers = {},
	}
end

local function decode(response): json.Object
	return assert(json.asObject(json.deserialize(response.body) :: json.Value))
end

-- A canvas named work with a Claude Code source and a card whose last session
-- ran in a folder still on agent/fix.
local function setUp(name: string): (string, string)
	local root = testing.directory(name)
	local folder = testing.directory(`{name}-checkout`)
	fs.createDirectory(folder, { makeParents = true })
	local doc = testing.createDoc({
		testing.task("fix", "Fix", "active", nil, {
			repo = "owner/repo",
			refs = {
				json.object({ source = "branch", kind = "branch", key = "owner/repo@agent/fix" }),
				json.object({
					source = "claude",
					kind = "session",
					key = "Fix",
					details = json.object({ cwd = folder }),
				}),
			},
		}),
	})
	doc.settings.sources = { { id = "claude", kind = "claude" } }
	createWorkspace(root, "work")
	writeDoc(getWorkspaceDir(root, "work"), doc)
	return root, folder
end

test.case("the app learns which presets fit a card and where it would start", function(assert)
	local root, folder = setUp("route-session-start-get")
	local function run()
		return testing.result(true, "agent/fix\n")
	end

	local response = sessionStart.handleAsync(request("GET", { id = "fix" }), root, "work", run)
	local body = decode(response)
	local first = json.asObject((json.asArray(body.presets) or {})[1])

	assert.eq(response.status, 200)
	assert.eq(body.agent, "Claude Code")
	assert.eq(body.folder, folder)
	assert.eq(body.problem, json.null)
	assert.eq(first and first.id, "work")
	assert.eq(sessionStart.handleAsync(request("GET", { id = "nope" }), root, "work", run).status, 404)
	assert.eq(sessionStart.handleAsync(request("GET", { id = "fix" }), root, "missing", run).status, 404)
	fs.removeDirectory(folder, { recursive = true })
end)

test.case("posting a preset opens the agent, and a refusal says why", function(assert)
	local root, folder = setUp("route-session-start-post")
	local opened: { string }? = nil
	local function run(argv: { string })
		if argv[1] ~= "git" then
			opened = argv
		end

		return testing.result(true, "agent/fix\n")
	end

	local response =
		sessionStart.handleAsync(request("POST", {}, json.object({ id = "fix", preset = "work" })), root, "work", run)
	local body = decode(response)

	assert.eq(response.status, 200)
	assert.eq(body.folder, folder)
	assert.eq(opened and opened[#opened], body.url)

	local refused = sessionStart.handleAsync(
		request("POST", {}, json.object({ id = "fix", preset = "resolve-conflicts" })),
		root,
		"work",
		run
	)

	assert.eq(refused.status, 409)
	assert.strContains(tostring(decode(refused).error), "doesn't fit")
	assert.eq(sessionStart.handleAsync(request("DELETE", {}), root, "work", run).status, 405)
	fs.removeDirectory(folder, { recursive = true })
end)
