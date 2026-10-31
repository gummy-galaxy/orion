local json = require("@std/json")
local test = require("@std/test")

local changeCheckSnooze = require("@root/sources/github/checks/changeCheckSnooze")
local testing = require("@root/testing")

test.case("snoozing a job again replaces its snooze and starts it over", function(assert)
	local doc = testing.createDoc({})
	changeCheckSnooze(doc, { repo = "vocksel/orion", name = "docs", snoozed = true, at = "2026-10-13T00:00:00Z" })
	table.insert(doc.settings.checkSnoozes[1].passed, "card")
	changeCheckSnooze(doc, {
		repo = "Vocksel/Orion",
		name = "docs",
		snoozed = true,
		untilTime = "2026-10-14T00:00:00Z",
		at = "2026-10-13T01:00:00Z",
	})

	assert.eq(#doc.settings.checkSnoozes, 1)
	assert.eq(doc.settings.checkSnoozes[1].untilTime, "2026-10-14T00:00:00Z")
	assert.eq(#doc.settings.checkSnoozes[1].passed, 0)
end)

test.case("unsnoozing removes only that job in that repository", function(assert)
	local doc = testing.createDoc({})
	changeCheckSnooze(doc, { repo = "vocksel/orion", name = "docs", snoozed = true, at = "now" })
	changeCheckSnooze(doc, { repo = "vocksel/hop", name = "docs", snoozed = true, at = "now" })
	changeCheckSnooze(doc, { repo = "vocksel/orion", name = "docs", snoozed = false, at = "now" })

	assert.eq(#doc.settings.checkSnoozes, 1)
	assert.eq(doc.settings.checkSnoozes[1].repo, "vocksel/hop")
end)

test.case("a snooze needs a repository and a job name", function(assert)
	local doc = testing.createDoc({})
	assert.throwsWith("isn't a repository such as owner/name", function()
		changeCheckSnooze(doc, { repo = "orion", name = "docs", snoozed = true, at = "now" })
	end)
	assert.throwsWith("needs the job's name", function()
		changeCheckSnooze(doc, { repo = "vocksel/orion", name = "", snoozed = true, at = "now" })
	end)
end)

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
