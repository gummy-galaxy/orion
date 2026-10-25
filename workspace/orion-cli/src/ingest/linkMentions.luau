local adapterTypes = require("@root/adapters/types")
local findRef = require("@root/refs/findRef")
local getGithubKey = require("@root/refs/getGithubKey")
local ingestTypes = require("@root/ingest/types")
local linkItems = require("@root/graph/linkItems")
local types = require("@root/types")

type Record = adapterTypes.Record
type SourceReport = ingestTypes.SourceReport
type Doc = types.Doc
type Item = types.Item

local function linkMentions(doc: Doc, entries: { { record: Record, item: Item, report: SourceReport } })
	local function findIssue(key: string): Item?
		for _, item in doc.nodes do
			if item.type == "task" and findRef(item, "issue", key) then
				return item
			end
		end

		return nil
	end

	local function link(from: Item, to: Item, report: SourceReport)
		if from.id == to.id then
			return
		end

		for _, existing in doc.links do
			if
				existing.from == from.id and existing.to == to.id
				or existing.from == to.id and existing.to == from.id
			then
				return
			end
		end

		linkItems(doc, from.id, to.id, "related").origin = "mention"
		report.linked += 1
	end

	for _, entry in entries do
		local mentionText = entry.record.mentionText

		if not mentionText then
			continue
		end

		for key in mentionText:upper():gmatch("%f[%w][A-Z][A-Z0-9]*%-%d+%f[^%w]") do
			local issue = findIssue(key)

			if issue then
				link(issue, entry.item, entry.report)
			end
		end

		local ref = entry.record.ref
		local key = ref.key
		local host, owner, name = key:match("^([^/]+)/([^/]+)/([^/]+)#")

		if not name then
			owner, name = key:match("^([^/]+)/([^/]+)#")
			host = "github.com"
		end

		if not owner or not name then
			continue
		end

		local repo = string.lower(`{owner}/{name}`)

		for mentionedOwner, mentionedName, number in mentionText:gmatch("([%w_.%-]+)/([%w_.%-]+)#(%d+)") do
			if string.lower(`{mentionedOwner}/{mentionedName}`) == repo then
				local issue = findIssue(getGithubKey(assert(owner), assert(name), `#{number}`, assert(host)))

				if issue then
					link(issue, entry.item, entry.report)
				end
			end
		end

		local bare = mentionText:gsub("[%w_.%-]+/[%w_.%-]+#%d+", "")

		for number in bare:gmatch("#(%d+)") do
			local issue = findIssue(getGithubKey(assert(owner), assert(name), `#{number}`, assert(host)))

			if issue then
				link(issue, entry.item, entry.report)
			end
		end
	end
end

return linkMentions
