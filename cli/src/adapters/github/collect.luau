local json = require("@std/json")

local adapterTypes = require("@root/adapters/types")
local findBranch = require("@root/adapters/findBranch")
local findRef = require("@root/refs/findRef")
local getDesired = require("@root/github/getDesired")
local getGithubKey = require("@root/refs/getGithubKey")
local getInvolved = require("@root/github/getInvolved")
local setPullRef = require("@root/github/setPullRef")
local types = require("@root/types")

type Record = adapterTypes.Record
type Context = adapterTypes.Context
type Doc = types.Doc
type Item = types.Item
type Ref = types.Ref
type Source = types.Source
type CommandRunner = types.CommandRunner

local function collect(source: Source, run: CommandRunner, context: Context): { Record }
	local pulls, issues, viewer =
		getInvolved(run, assert(source.host), assert(source.owners), context.since, source.include, source.exclude)
	local records: { Record } = {}

	for _, pull in pulls do
		local repo = `{pull.owner}/{pull.name}`
		local key = getGithubKey(pull.owner, pull.name, `#{pull.number}`, pull.host)
		local existing: Ref? = nil

		for _, item in context.doc.nodes do
			if item.type == "task" and findRef(item, "pull", key) then
				existing = findRef(item, "pull", key)
				break
			end
		end

		local temporary: Item = {
			id = "",
			type = "task",
			position = { x = 0, y = 0 },
			data = json.object({ refs = if existing then { existing } else {} }),
		}
		setPullRef(temporary, pull, source.id, viewer, context.now)
		local ref = assert(findRef(temporary, "pull", key))
		table.insert(records, {
			ref = ref,
			label = pull.title,
			repo = repo,
			itemKind = "pr",
			createStatus = "todo",
			findFallback = function(doc: Doc)
				local item = if pull.branch then findBranch(doc, repo, pull.branch) else nil
				return if item and not findRef(item, "pull") then item else nil
			end,
			getStatus = function(status: string, who: string?): (string, string?)
				return getDesired(pull, status, who, viewer)
			end,
			mentionText = `{pull.title} {pull.branch or ""} {pull.body or ""}`,
		})
	end

	for _, issue in issues do
		table.insert(records, {
			ref = {
				source = source.id,
				kind = "issue",
				key = getGithubKey(issue.owner, issue.name, `#{issue.number}`, issue.host),
				url = issue.url,
			},
			label = issue.title,
			repo = `{issue.owner}/{issue.name}`,
			itemKind = "placeholder",
			createStatus = "todo",
			createWho = "you",
		})
	end

	return records
end

return collect
