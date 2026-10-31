local test = require("@std/test")

local adapterTypes = require("@root/sources/types")
local ingestTypes = require("@root/sources/ingest/types")
local linkMentions = require("@root/sources/ingest/linkMentions")
local testing = require("@root/testing")

type Record = adapterTypes.Record
type SourceReport = ingestTypes.SourceReport

test.case("linkMentions finds Jira and same-repo GitHub issues once", function(assert)
	local pull = testing.task("pull", "Pull", "active")
	local jira =
		testing.task("jira", "Jira", "todo", nil, { refs = { { source = "jira", kind = "issue", key = "ABC-1" } } })
	local issue = testing.task(
		"issue",
		"GitHub issue",
		"todo",
		nil,
		{ refs = { { source = "github", kind = "issue", key = "owner/repo#7" } } }
	)
	local doc = testing.createDoc({ pull, jira, issue })
	local report: SourceReport = { id = "github", added = 0, updated = 0, linked = 0 }
	local record: Record = {
		ref = { source = "github", kind = "pull", key = "owner/repo#8" },
		label = "Pull",
		mentionText = "ABC-1 closes owner/repo#7 and #7, ignores other/repo#9",
	}
	linkMentions(doc, { { record = record, item = pull, report = report } })
	assert.eq(report.linked, 2)
	assert.eq(#doc.links, 2)
	assert.eq(doc.links[1].origin, "mention")
	linkMentions(doc, { { record = record, item = pull, report = report } })
	assert.eq(report.linked, 2)
end)
