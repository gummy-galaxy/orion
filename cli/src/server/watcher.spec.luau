local task = require("@std/task")
local test = require("@std/test")

local store = require("@root/store")
local testing = require("@root/testing")
local watcher = require("@root/server/watcher")

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
	task.wait(0.3)
	expect.eq(#workspaceLists, 1)
	expect.eq(workspaceLists[1].workspaces[3].name, "new")
	store.transaction(root, function() end)
	task.wait(0.3)
	expect.eq(#revisions, 1)
	expect.eq(revisions[1], 1)
	store.useWorkspace(root, "other")
	task.wait(0.3)
	expect.eq(active, "other")
	expect.eq(#workspaceLists, 2)
	expect.eq(workspaceLists[2].active, "other")
	store.transaction(root, function() end)
	store.transaction(store.getWorkspaceDir(root, "other"), function() end)
	task.wait(0.3)
	expect.eq(#revisions, 2)
	expect.eq(revisions[2], 1)
	monitor.close()
end)
