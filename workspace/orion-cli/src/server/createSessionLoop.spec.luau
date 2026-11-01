local fs = require("@std/fs")
local json = require("@std/json")
local task = require("@std/task")
local test = require("@std/test")

local createSessionLoop = require("@root/server/createSessionLoop")
local findRef = require("@root/canvas/refs/findRef")
local getWorkspaceDir = require("@root/storage/canvases/getWorkspaceDir")
local loadDoc = require("@root/storage/canvases/loadDoc")
local testing = require("@root/testing")
local writeDoc = require("@root/storage/canvases/writeDoc")

local WAIT_STEP_SECONDS = 0.05
local WAIT_LIMIT_SECONDS = 3

local function waitUntil(condition: () -> boolean)
	for _ = 1, math.ceil(WAIT_LIMIT_SECONDS / WAIT_STEP_SECONDS) do
		if condition() then
			return
		end

		task.wait(WAIT_STEP_SECONDS)
	end
end

-- A canvas with one card on agent/fix and a Claude Code source reading a
-- fixture folder whose process is `status`.
local function setUp(name: string, status: string): (string, string)
	local root = testing.directory(name)
	local claudeDir = testing.directory(`{name}-claude`)
	testing.writeClaudeFixture(claudeDir, { branch = "agent/fix", stop = "tool_use", status = status })
	local card = testing.task("fix", "Fix", "active", nil, json.object({ repo = "owner/repo" }))
	card.data.refs = { json.object({ source = "branch", kind = "branch", key = "owner/repo@agent/fix" }) } :: json.Array
	local doc = testing.createDoc({ card })
	doc.settings.sources = { { id = "claude", kind = "claude", dir = claudeDir } }
	writeDoc(root, doc)
	return root, claudeDir
end

-- Every fixture process is alive, through `kill -0` or Windows' `tasklist`.
local function run(argv: { string })
	if argv[1] == "tasklist" then
		return testing.result(true, '"42"')
	end

	return testing.result(argv[1] == "kill" or argv[1] == "git", "git@github.com:owner/repo.git\n")
end

local function getState(root: string): string?
	local doc = loadDoc(getWorkspaceDir(root, "default"))
	local ref = findRef(doc.nodes[1], "session")
	return if ref then ref.sessionState else nil
end

test.case("a refresh writes only when a session ref's facts change", function(assert)
	local root, claudeDir = setUp("server-sessions", "busy")
	local sessionLoop = createSessionLoop(root, function()
		return "default"
	end, run)

	assert.eq(sessionLoop.refreshAsync(), true)
	assert.eq(getState(root), "working")

	local revision = loadDoc(getWorkspaceDir(root, "default")).revision
	assert.eq(sessionLoop.refreshAsync(), false)
	assert.eq(loadDoc(getWorkspaceDir(root, "default")).revision, revision)

	testing.writeClaudeFixture(claudeDir, { branch = "agent/fix", stop = "tool_use", status = "idle" })
	assert.eq(sessionLoop.refreshAsync(), true)
	assert.eq(getState(root), "waiting")
	sessionLoop.close()
	fs.removeDirectory(claudeDir, { recursive = true })
end)

test.case("a change in the sessions folder refreshes on its own", function(assert)
	local root, claudeDir = setUp("server-sessions-watch", "busy")
	local sessionLoop = createSessionLoop(root, function()
		return "default"
	end, run)

	sessionLoop.start()
	waitUntil(function()
		return getState(root) == "working"
	end)
	assert.eq(getState(root), "working")

	testing.writeClaudeFixture(claudeDir, { branch = "agent/fix", stop = "tool_use", status = "idle" })
	waitUntil(function()
		return getState(root) == "waiting"
	end)
	assert.eq(getState(root), "waiting")
	sessionLoop.close()
	fs.removeDirectory(claudeDir, { recursive = true })
end)

test.case("a canvas with no agent sources is never written", function(assert)
	local root = testing.directory("server-sessions-none")
	writeDoc(root, testing.createDoc({}))
	local sessionLoop = createSessionLoop(root, function()
		return "default"
	end, run)

	assert.eq(sessionLoop.refreshAsync(), false)
	assert.eq(loadDoc(getWorkspaceDir(root, "default")).revision, 0)
	sessionLoop.close()
end)
