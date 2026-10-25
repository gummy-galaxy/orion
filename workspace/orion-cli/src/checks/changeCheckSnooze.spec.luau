local test = require("@std/test")

local changeCheckSnooze = require("@root/checks/changeCheckSnooze")
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
