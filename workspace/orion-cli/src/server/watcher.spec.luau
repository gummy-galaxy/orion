local fs = require("@std/fs")
local path = require("@std/path")
local task = require("@std/task")
local test = require("@std/test")

local appendLog = require("@root/log/appendLog")
local createWorkspace = require("@root/store/createWorkspace")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local runTransaction = require("@root/store/runTransaction")
local storeTypes = require("@root/store/types")
local testing = require("@root/testing")
local useWorkspace = require("@root/store/useWorkspace")
local watcher = require("@root/server/watcher")
local writeDoc = require("@root/store/writeDoc")

type WorkspaceList = storeTypes.WorkspaceList

local WAIT_STEP_SECONDS = 0.05
local WAIT_LIMIT_SECONDS = 3

-- Polls rather than sleeping a fixed time so slow runners get longer without slowing fast ones.
local function waitUntil(condition: () -> boolean)
	for _ = 1, math.ceil(WAIT_LIMIT_SECONDS / WAIT_STEP_SECONDS) do
		if condition() then
			return
		end

		task.wait(WAIT_STEP_SECONDS)
	end
end

test.case("watcher announces external edits and follows manifest switches", function(expect)
	local root = testing.directory("server-watcher")
	writeDoc(root, testing.createDoc({}, {}))
	createWorkspace(root, "other")
	local active = "default"
	local revisions: { number } = {}
	local workspaceLists: { WorkspaceList } = {}
	local monitor
	monitor = watcher.create(root, function()
		return active
	end, function(name)
		active = name
		assert(monitor).switchTo(name)
	end, function(revision)
		table.insert(revisions, revision)
	end, function(list)
		table.insert(workspaceLists, list)
	end, function() end)

	monitor.start()
	createWorkspace(root, "new")
	waitUntil(function()
		return #workspaceLists >= 1
	end)
	expect.eq(#workspaceLists, 1)
	expect.eq(workspaceLists[1].workspaces[3].name, "new")
	runTransaction(root, function() end)
	waitUntil(function()
		return #revisions >= 1
	end)
	expect.eq(#revisions, 1)
	expect.eq(revisions[1], 1)
	useWorkspace(root, "other")
	waitUntil(function()
		return active == "other" and #workspaceLists >= 2
	end)
	expect.eq(active, "other")
	expect.eq(#workspaceLists, 2)
	expect.eq(workspaceLists[2].active, "other")
	runTransaction(root, function() end)
	runTransaction(getWorkspaceDir(root, "other"), function() end)
	waitUntil(function()
		return #revisions >= 2
	end)
	expect.eq(#revisions, 2)
	expect.eq(revisions[2], 1)
	monitor.close()
end)

test.case("watcher announces log appends for the canvas they land in, not document revisions", function(expect)
	local root = testing.directory("server-watcher-log")
	writeDoc(root, testing.createDoc({}, {}))
	createWorkspace(root, "other")
	local active = "default"
	local revisions: { number } = {}
	local logNames: { string } = {}
	local monitor
	monitor = watcher.create(root, function()
		return active
	end, function(name)
		active = name
		assert(monitor).switchTo(name)
	end, function(revision)
		table.insert(revisions, revision)
	end, function() end, function(name)
		table.insert(logNames, name)
	end)

	monitor.start()
	appendLog(root, function()
		return {
			id = "log-1",
			text = "First",
			time = "2026-10-12T18:00:00Z",
			author = { kind = "person", name = "marin" },
			targets = {},
		}
	end)
	waitUntil(function()
		return #logNames >= 1
	end)
	expect.eq(logNames[1], "default")
	expect.eq(#revisions, 0)

	useWorkspace(root, "other")
	waitUntil(function()
		return active == "other"
	end)
	appendLog(getWorkspaceDir(root, "other"), function()
		return {
			id = "log-1",
			text = "Elsewhere",
			time = "2026-10-12T19:00:00Z",
			author = { kind = "agent", name = "claude" },
			targets = {},
		}
	end)
	waitUntil(function()
		return #logNames >= 2
	end)
	expect.eq(logNames[#logNames], "other")
	expect.eq(#revisions, 0)
	monitor.close()
end)

test.case("watcher announces node and link files changed outside Orion without a new revision", function(expect)
	local root = testing.directory("server-watcher-pull")
	writeDoc(
		root,
		testing.createDoc({ testing.task("a", "A", "todo"), testing.task("b", "B", "todo") }, { { "a", "b" } })
	)
	local announced: { { revision: number, labels: string, isReindexed: boolean } } = {}
	local monitor = watcher.create(root, function()
		return "default"
	end, function() end, function(revision, doc, isReindexed)
		local labels = {}

		for _, node in doc.nodes do
			table.insert(labels, node.data.label :: string)
		end

		table.insert(announced, { revision = revision, labels = table.concat(labels, ","), isReindexed = isReindexed })
	end, function() end, function() end)

	monitor.start()

	-- What a `git pull` does to the folder: one card changes, one arrives, and one goes with its link.
	local nodes = path.join(root, "nodes")
	local changed = fs.readFileToString(path.join(nodes, "a.json")):gsub('"A"', '"A pulled"')
	fs.writeStringToFile(path.join(nodes, "a.json"), changed)
	fs.writeStringToFile(path.join(nodes, "c.json"), (changed:gsub('"a"', '"c"'):gsub("A pulled", "C")))
	fs.remove(path.join(nodes, "b.json"))
	fs.remove(path.join(root, "links", "a%3eb.json"))

	waitUntil(function()
		return #announced >= 1 and announced[#announced].labels == "A pulled,C"
	end)
	monitor.close()

	local last = announced[#announced]
	expect.eq(last.labels, "A pulled,C")
	expect.eq(last.revision, 0)
	expect.eq(last.isReindexed, true)
end)
