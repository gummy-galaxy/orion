local json = require("@std/json")

local findBranchCards = require("@root/sources/github/pulls/findBranchCards")
local getKey = require("@root/sources/github/refs/getKey")
local getLabel = require("@root/canvas/items/getLabel")
local getRefFor = require("@root/sources/github/refs/getRefFor")
local getString = require("@root/sources/github/getString")
local githubTypes = require("@root/sources/github/types")
local isInSources = require("@root/sources/github/repositories/isInSources")
local linkItems = require("@root/canvas/links/linkItems")
local match = require("@root/canvas/query/match")
local refreshItemKind = require("@root/canvas/items/refreshItemKind")
local setDesired = require("@root/sources/github/pulls/setDesired")
local setPullRef = require("@root/sources/github/pulls/setPullRef")
local types = require("@root/types")

type PullState = githubTypes.PullState
type Fetched = githubTypes.Fetched
type Report = githubTypes.Report
type Doc = types.Doc
type Item = types.Item

-- Moves a card's status and whose move it is to match the pull request,
-- recording any change.
local function applyDesired(item: Item, pull: PullState, viewer: string, report: Report)
	local status, who = getString(item.data.status) or "todo", getString(item.data.who)
	setDesired(item, pull, viewer)
	local nextStatus, nextWho = getString(item.data.status) or "todo", getString(item.data.who)

	if nextStatus ~= status or nextWho ~= who then
		table.insert(report.changes, {
			id = item.id,
			label = getLabel(item),
			fromStatus = status,
			toStatus = nextStatus,
			fromWho = who,
			toWho = nextWho,
			closed = pull.state == "CLOSED",
		})
	end
end

-- Attaches a new pull request to the card its head branch was recorded on, as
-- `--ref branch:` does.
local function attachByBranch(item: Item, pull: PullState, fetched: Fetched, checkedAt: string, report: Report)
	local repo = `{pull.owner}/{pull.name}`
	applyDesired(item, pull, fetched.viewer, report)
	setPullRef(item, pull, "github", fetched.viewer, checkedAt)

	if item.data.repo == nil then
		item.data.repo = repo
	end

	refreshItemKind(item)
	table.insert(report.attached, { id = item.id, pull = `{repo}#{pull.number}` })
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
	for _, pull in fetched.authored or {} do
		local key = getKey(pull)
		if not pulls[key] then
			pulls[key] = pull
		end
	end

	local cards: { { id: string, pull: PullState } } = {}
	local byId: { [string]: PullState } = {}

	for _, item in doc.nodes do
		local ref = getRefFor(item)
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
				linkItems(doc, parent.id, child.id, "blocks").origin = "stack"
				table.insert(report.linked, { from = parent.id, to = child.id })
			end
		end
	end
end

local function applyPulls(doc: Doc, fetched: Fetched, checkedAt: string): Report
	local report: Report = {
		changes = {},
		missing = {},
		attached = {},
		linked = {},
		unlinked = {},
		checked = 0,
		failures = {},
	}
	local onCanvas: { [string]: boolean } = {}

	for _, item in doc.nodes do
		local ref = getRefFor(item)

		if not ref then
			continue
		end

		local key = getKey(ref)
		onCanvas[key] = true
		local pull = fetched.pulls[key]

		-- A card that wasn't fetched keeps its state: it's merged, its batch
		-- failed, or it was added after the fetch.
		if not pull then
			if fetched.checked[key] then
				table.insert(report.missing, item.id)
			end

			continue
		end

		report.checked += 1
		applyDesired(item, pull, fetched.viewer, report)
		setPullRef(item, pull, "github", fetched.viewer, checkedAt)
	end

	local previous = json.asObject(doc.github)
	-- Without a fresh authored list, the unplaced list recorded last time
	-- stands.
	local unplaced: json.Array = if fetched.authored == nil and previous
		then table.clone(json.asArray(previous.unplaced) or {})
		else {}

	for _, pull in fetched.authored or {} do
		local key = getKey(pull)
		if onCanvas[key] or not isInSources(doc, pull) then
			continue
		end

		-- Only a pull request with its full state, fetched for this, attaches
		-- to its branch's card. Otherwise it stays unplaced.
		local repo = `{pull.owner}/{pull.name}`
		local branchCards = findBranchCards(doc, pull)
		local full = fetched.pulls[key]

		if full and #branchCards == 1 then
			attachByBranch(branchCards[1], full, fetched, checkedAt, report)
			onCanvas[key] = true
			continue
		end

		local candidates: json.Array = {}

		-- Several cards on one branch are a tie, so they're the only candidates
		-- listed.
		if #branchCards > 1 then
			for _, card in branchCards do
				table.insert(candidates, json.object({ id = card.id, score = 1 }))
			end
		else
			for _, candidate in match.candidates(doc, pull.title, pull.owner, pull.name) do
				table.insert(candidates, json.object({ id = candidate.id, score = candidate.score }))
			end
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

	syncStackLinks(doc, fetched, report)
	table.move(fetched.failures, 1, #fetched.failures, 1, report.failures)
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
