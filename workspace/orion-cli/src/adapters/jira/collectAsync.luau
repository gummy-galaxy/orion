local json = require("@std/json")

local adapterTypes = require("@root/adapters/types")
local getCommandJsonAsync = require("@root/adapters/getCommandJsonAsync")
local parseIssues = require("@root/adapters/jira/parseIssues")
local types = require("@root/types")

type Record = adapterTypes.Record
type Context = adapterTypes.Context
type Source = types.Source
type CommandRunner = types.CommandRunner

local function collectAsync(source: Source, run: CommandRunner, context: Context): { Record }
	local command = context.commands[source.id]
	assert(
		command,
		`the {source.id} source has no command on this machine; set one with `
			.. `orion source add jira --id {source.id} --command '["acli","jira","workitem","search","--json"]'`
	)
	local issues = parseIssues(getCommandJsonAsync(run, command))
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
				type = "step",
				key = issue.key,
				url = if source.browse then `{source.browse}/{issue.key}` else nil,
				status = issue.status,
				isDone = issue.category == "done",
				updatedAt = issue.updated,
				details = details,
			},
			label = issue.summary,
			status = status,
			who = if status == "done" then nil else "you",
			createStatus = "todo",
			createWho = "you",
		})
	end

	return records
end

return collectAsync
