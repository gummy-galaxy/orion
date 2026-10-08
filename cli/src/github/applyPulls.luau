local getDesired = require("@root/github/getDesired")
local getKey = require("@root/github/getKey")
local getRecorded = require("@root/github/getRecorded")
local getRefFor = require("@root/github/getRefFor")
local getString = require("@root/github/getString")
local githubTypes = require("@root/github/types")
local graph = require("@root/graph")
local isListed = require("@root/github/isListed")
local json = require("@std/json")
local match = require("@root/match")
local types = require("@root/types")

type PullState = githubTypes.PullState
type Fetched = githubTypes.Fetched
type Report = githubTypes.Report
type Doc = types.Doc

local INBOX_ID = "inbox"

local function getRepoName(doc: Doc, pull: PullState): string
	return if pull.owner:lower() == doc.settings.githubOwner:lower() then pull.name else `{pull.owner}/{pull.name}`
end

local function ensureGroup(doc: Doc, id: string, label: string, blurb: string)
	if not graph.find(doc, id) then
		table.insert(doc.nodes, {
			id = id,
			type = "cluster",
			position = graph.nextSlot(doc, nil),
			data = json.object({ kind = "cluster", label = label, blurb = blurb }),
		})
	end
end

local function isStacked(parent: PullState, child: PullState): boolean
	return parent.owner:lower() == child.owner:lower()
		and parent.name:lower() == child.name:lower()
		and parent.number ~= child.number
		and parent.headRefName ~= ""
		and parent.headRefName == child.baseRefName
end

local function syncStackLinks(doc: Doc, fetched: Fetched, report: Report)
	local pulls = table.clone(fetched.pulls)
	for _, pull in fetched.authored do
		local key = getKey(pull)
		if not pulls[key] then
			pulls[key] = pull
		end
	end

	local cards: { { id: string, pull: PullState } } = {}
	local byId: { [string]: PullState } = {}

	for _, item in doc.nodes do
		local ref = getRefFor(item, doc.settings.githubOwner)
		local pull = if ref then pulls[getKey(ref)] else nil

		if pull then
			table.insert(cards, { id = item.id, pull = pull })
			byId[item.id] = pull
		end
	end

	for index = #doc.links, 1, -1 do
		local link = doc.links[index]

		if link.origin ~= "stack" then
			continue
		end

		local parent, child = byId[link.from], byId[link.to]

		if parent and child and parent.state == "OPEN" and child.state == "OPEN" and not isStacked(parent, child) then
			table.remove(doc.links, index)
			table.insert(report.unlinked, { from = link.from, to = link.to })
		end
	end

	for _, parent in cards do
		for _, child in cards do
			if not isStacked(parent.pull, child.pull) then
				continue
			end

			local isLinked = false

			for _, link in doc.links do
				if
					(link.from == parent.id and link.to == child.id) or (link.from == child.id and link.to == parent.id)
				then
					isLinked = true
					break
				end
			end

			if not isLinked then
				graph.link(doc, parent.id, child.id, "blocks").origin = "stack"
				table.insert(report.linked, { from = parent.id, to = child.id })
			end
		end
	end
end

-- Your own open pull requests only belong on a canvas whose GitHub sources cover their repository.
-- A canvas without GitHub sources takes them all.
local function isInSources(doc: Doc, pull: PullState): boolean
	local hasSources = false
	for _, source in doc.settings.sources do
		if source.kind ~= "github" or (source.host or "github.com") ~= "github.com" then
			continue
		end
		hasSources = true
		if
			isListed(source.owners, pull.owner)
			and (not source.include or isListed(source.include, pull.name))
			and not isListed(source.exclude, pull.name)
		then
			return true
		end
	end
	return not hasSources
end

local function applyPulls(doc: Doc, fetched: Fetched, checkedAt: string): Report
	local report: Report = { changes = {}, missing = {}, added = {}, linked = {}, unlinked = {}, checked = 0 }
	local onCanvas: { [string]: boolean } = {}

	for _, item in doc.nodes do
		local ref = getRefFor(item, doc.settings.githubOwner)

		if not ref then
			continue
		end

		local key = getKey(ref)
		onCanvas[key] = true
		local pull = fetched.pulls[key]

		if not pull then
			table.insert(report.missing, item.id)
			continue
		end

		report.checked += 1
		local status, who = getString(item.data.status) or "todo", getString(item.data.who)
		local nextStatus, nextWho = getDesired(pull, status, who, fetched.viewer)

		if nextStatus ~= status or nextWho ~= who then
			table.insert(report.changes, {
				id = item.id,
				label = graph.label(item),
				fromStatus = status,
				toStatus = nextStatus,
				fromWho = who,
				toWho = nextWho,
				closed = pull.state == "CLOSED",
			})
			item.data.status, item.data.who = nextStatus, nextWho
		end

		item.data.github = getRecorded(pull, fetched.viewer, checkedAt)
		item.data.branch = pull.branch or item.data.branch
	end

	local unplaced: json.Array = {}

	for _, pull in fetched.authored do
		local key = getKey(pull)
		if onCanvas[key] or not isInSources(doc, pull) then
			continue
		end

		local repo = getRepoName(doc, pull)

		if fetched.discover then
			ensureGroup(doc, INBOX_ID, "Inbox", "Open pull requests found on GitHub that aren't placed yet.")
			local status, who = getDesired(pull, "todo", nil, fetched.viewer)
			local item = graph.addItem(doc, pull.title, {
				group = INBOX_ID,
				repo = repo,
				pr = pull.number,
				status = status,
				who = who,
			})
			item.data.github = getRecorded(pull, fetched.viewer, checkedAt)
			item.data.branch = pull.branch
			onCanvas[key] = true
			table.insert(report.added, item.id)
		else
			local candidates: json.Array = {}

			for _, candidate in match.candidates(doc, pull.title, pull.owner, pull.name) do
				table.insert(candidates, json.object({ id = candidate.id, score = candidate.score }))
			end

			table.insert(
				unplaced,
				json.object({
					repo = repo,
					number = pull.number,
					title = pull.title,
					url = pull.url,
					draft = pull.draft,
					updatedAt = pull.updatedAt,
					additions = pull.additions,
					deletions = pull.deletions,
					matches = candidates,
				})
			)
		end
	end

	syncStackLinks(doc, fetched, report)
	table.sort(unplaced, function(a, b)
		local left, right = json.asObject(a), json.asObject(b)
		local leftTime: string = if left then getString(left.updatedAt) or "" else ""
		local rightTime: string = if right then getString(right.updatedAt) or "" else ""
		return (tonumber((leftTime:gsub("%D", ""))) or 0) > (tonumber((rightTime:gsub("%D", ""))) or 0)
	end)

	doc.github = json.object({ viewer = fetched.viewer, checkedAt = checkedAt, unplaced = unplaced })
	return report
end

return applyPulls
