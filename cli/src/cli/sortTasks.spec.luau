local test = require("@std/test")

local derive = require("@root/graph/derive")
local sortTasks = require("@root/cli/sortTasks")
local testing = require("@root/testing")

test.case("sortTasks keeps cards that pass, the ones that unblock the most first", function(assert)
	local doc = testing.createDoc({
		testing.task("b", "B", "todo"),
		testing.task("a", "A", "todo"),
		testing.task("root", "Root", "todo"),
		testing.task("skip", "Skip", "todo"),
		testing.group("group", "Group"),
	}, { { "root", "a" }, { "root", "b" } })

	local items = sortTasks(doc, derive(doc), function(item)
		return item.id ~= "skip"
	end)
	local ids = {}

	for _, item in items do
		table.insert(ids, item.id)
	end

	assert.eq(table.concat(ids, ","), "root,a,b")
end)
