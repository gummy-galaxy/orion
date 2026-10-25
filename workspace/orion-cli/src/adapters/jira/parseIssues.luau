local json = require("@std/json")

local jiraTypes = require("@root/adapters/jira/types")

type JiraIssue = jiraTypes.JiraIssue

local function getString(value: json.Value): string?
	return if type(value) == "string" then value else nil
end

local function parseIssues(value: json.Value): { JiraIssue }
	local root = json.asObject(value)
	local array = if root then json.asArray(root.issues) else json.asArray(value)
	assert(array, "Jira response must be an array or contain issues")
	local result = {}

	for _, raw in array do
		local issue = json.asObject(raw)
		local fields = if issue then json.asObject(issue.fields) else nil
		local key = if issue then getString(issue.key) else nil
		local summary = (if issue then getString(issue.summary) else nil)
			or (if fields then getString(fields.summary) else nil)
		local status = if fields then json.asObject(fields.status) else nil
		local category = if status then json.asObject(status.statusCategory) else nil
		local categoryKey = (if issue then getString(issue.statusCategory) else nil)
			or (if category then getString(category.key) else nil)
		local issueType = if fields then json.asObject(fields.issuetype) else nil

		if not key or not summary then
			continue
		end

		local epic = if fields then json.asObject(fields.epic) or json.asObject(fields.parent) else nil
		local epicFields = if epic then json.asObject(epic.fields) else nil
		table.insert(result, {
			key = key,
			summary = summary,
			status = (if issue then getString(issue.status) else nil) or (if status
				then getString(status.name)
				else nil) or "",
			category = if categoryKey == "done" or categoryKey == "indeterminate" then categoryKey else "new",
			issueType = (if issue then getString(issue.type) else nil) or (if issueType
				then getString(issueType.name)
				else nil) or "",
			epicKey = (if issue then getString(issue.epicKey) else nil) or (if epic then getString(epic.key) else nil),
			epicSummary = (if issue then getString(issue.epicSummary) else nil) or (if epic
				then getString(epic.summary) or getString(epic.name) or (if epicFields
					then getString(epicFields.summary)
					else nil)
				else nil),
			updated = (if issue then getString(issue.updatedAt) else nil)
				or (if fields then getString(fields.updated) else nil),
		})
	end

	return result
end

return parseIssues
