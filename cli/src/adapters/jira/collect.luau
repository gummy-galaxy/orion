local json = require("@std/json")

local adapterTypes = require("@root/adapters/types")
local getCommandJson = require("@root/adapters/getCommandJson")
local parseIssues = require("@root/adapters/jira/parseIssues")
local types = require("@root/types")

type Record = adapterTypes.Record
type Context = adapterTypes.Context
type Source = types.Source
type CommandRunner = types.CommandRunner

local function collect(source: Source, run: CommandRunner, _context: Context): { Record }
	local issues = parseIssues(getCommandJson(run, assert(source.command)))
	local records: { Record } = {}

	for _, issue in issues do
		local status = if issue.category == "done"
			then "done"
			elseif issue.category == "indeterminate" then "active"
			else "todo"
		local details = json.object({ type = issue.issueType })
		details.epicKey = issue.epicKey
		details.epicSummary = issue.epicSummary
		table.insert(records, {
			ref = {
				source = source.id,
				kind = "issue",
				key = issue.key,
				url = if source.browse then `{source.browse}/{issue.key}` else nil,
				status = issue.status,
				isDone = issue.category == "done",
				updatedAt = issue.updated,
				details = details,
			},
			label = issue.summary,
			itemKind = "step",
			status = status,
			who = if status == "done" then nil else "you",
			createStatus = "todo",
			createWho = "you",
		})
	end

	return records
end

return collect
