local json = require("@std/json")
local test = require("@std/test")

local changeCheckSnooze = require("@root/checks/changeCheckSnooze")
local testing = require("@root/testing")

test.case("a snooze named by its repository's old name is kept under the current one", function(assert)
	local doc = testing.createDoc({})
	doc.repositories = json.object({
		["1"] = json.object({ name = "gummy-galaxy/orion", aliases = { "vocksel/orion" } }),
	})
	local snoozes = doc.settings.checkSnoozes

	changeCheckSnooze(doc, { repo = "vocksel/orion", name = "lint", snoozed = true, at = "now" })
	assert.eq(#snoozes, 1)
	assert.eq(snoozes[1].repo, "gummy-galaxy/orion")

	changeCheckSnooze(doc, { repo = "Vocksel/Orion", name = "lint", snoozed = false, at = "later" })
	assert.eq(#snoozes, 0)
end)

test.case("a repository the directory doesn't know is kept as given", function(assert)
	local doc = testing.createDoc({})

	changeCheckSnooze(doc, { repo = "flipbook-labs/flipbook", name = "lint", snoozed = true, at = "now" })

	assert.eq(doc.settings.checkSnoozes[1].repo, "flipbook-labs/flipbook")
end)
