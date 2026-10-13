local task = require("@std/task")
local test = require("@std/test")

local store = require("@root/store")
local testing = require("@root/testing")
local watcher = require("@root/server/watcher")

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
	store.write(root, testing.createDoc({}, {}))
	store.createWorkspace(root, "other")
	local active = "default"
	local revisions: { number } = {}
	local workspaceLists: { store.WorkspaceList } = {}
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
	end)

	monitor.start()
	store.createWorkspace(root, "new")
	waitUntil(function()
		return #workspaceLists >= 1
	end)
	expect.eq(#workspaceLists, 1)
	expect.eq(workspaceLists[1].workspaces[3].name, "new")
	store.transaction(root, function() end)
	waitUntil(function()
		return #revisions >= 1
	end)
	expect.eq(#revisions, 1)
	expect.eq(revisions[1], 1)
	store.useWorkspace(root, "other")
	waitUntil(function()
		return active == "other" and #workspaceLists >= 2
	end)
	expect.eq(active, "other")
	expect.eq(#workspaceLists, 2)
	expect.eq(workspaceLists[2].active, "other")
	store.transaction(root, function() end)
	store.transaction(store.getWorkspaceDir(root, "other"), function() end)
	waitUntil(function()
		return #revisions >= 2
	end)
	expect.eq(#revisions, 2)
	expect.eq(revisions[2], 1)
	monitor.close()
end)
