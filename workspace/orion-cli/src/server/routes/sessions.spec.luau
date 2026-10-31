local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@lute/net/server")
local test = require("@std/test")

local createWorkspace = require("@root/storage/canvases/createWorkspace")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local sessions = require("@root/server/routes/sessions")
local testing = require("@root/testing")
local writeDoc = require("@root/storage/canvases/writeDoc")

local function request(query: { [string]: string }, method: string?): net.ReceivedRequest
	return { method = method or "GET", path = "/api/sessions/turns", body = "", query = query, headers = {} }
end

local function decode(response): json.Object
	return assert(json.asObject(json.deserialize(response.body) :: json.Value))
end

local function run()
	return testing.result(false, "")
end

test.case("a session's turns are read live from its agent", function(assert)
	local root = testing.directory("route-sessions")
	local claudeDir = testing.directory("route-sessions-claude")
	local sessionId = testing.writeClaudeFixture(claudeDir, { branch = "agent/fix", stop = "end_turn" })
	local doc = testing.createDoc({})
	doc.settings.sources = { { id = "claude", kind = "claude", dir = claudeDir } }
	createWorkspace(root, "work")
	writeDoc(getWorkspaceDir(root, "work"), doc)

	local id = `claude:{sessionId}`
	local response = sessions.handleAsync(request({ source = "claude", id = id, limit = "1" }), root, "work", run)
	local turns = json.asArray(decode(response).turns) or {}
	local last = json.asObject(turns[1])

	assert.eq(response.status, 200)
	assert.eq(#turns, 1)
	assert.eq(last and last.role, "agent")
	assert.eq(last and last.text, "On it.")

	assert.eq(sessions.handleAsync(request({ source = "claude", id = "claude:0000" }), root, "work", run).status, 404)
	assert.eq(sessions.handleAsync(request({ source = "other", id = id }), root, "work", run).status, 404)
	assert.eq(sessions.handleAsync(request({ source = "claude", id = id }), root, "missing", run).status, 404)
	assert.eq(sessions.handleAsync(request({}, "POST"), root, "work", run).status, 405)
	fs.removeDirectory(claudeDir, { recursive = true })
end)
