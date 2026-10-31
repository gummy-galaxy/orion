local json = require("@std/json")

local addItem = require("@root/canvas/items/addItem")
local findItem = require("@root/canvas/items/findItem")
local findRef = require("@root/canvas/refs/findRef")
local findRepository = require("@root/sources/github/repositories/findRepository")
local findSameRef = require("@root/canvas/refs/findSameRef")
local getItem = require("@root/canvas/items/getItem")
local getNextSlot = require("@root/canvas/placement/getNextSlot")
local identifyRef = require("@root/sources/github/refs/identifyRef")
local ingestTypes = require("@root/sources/ingest/types")
local linkMentions = require("@root/sources/ingest/linkMentions")
local setRef = require("@root/canvas/refs/setRef")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item
type Result = ingestTypes.Result
type Report = ingestTypes.Report

local function createItem(doc: Doc, label: string, repo: string?, status: string, who: string?): Item
	if not findItem(doc, "unsorted") then
		table.insert(doc.nodes, {
			id = "unsorted",
			type = "cluster",
			position = getNextSlot(doc, nil),
			data = json.object({ kind = "cluster", label = "Unsorted" }),
		})
	end

	local unsorted = getItem(doc, "unsorted")

	if unsorted.data.layout == nil then
		unsorted.data.layout = "refit"
	end

	return addItem(doc, label, { group = "unsorted", repo = repo, status = status, who = who })
end

local function placeRecords(doc: Doc, results: { Result }): Report
	local pendingLinks = {}
	local reports = {}
	local ordered: { { result: Result, index: number } } = {}

	for index, result in results do
		table.insert(reports, result.report)
		table.insert(ordered, { result = result, index = index })
	end

	table.sort(ordered, function(left: { result: Result, index: number }, right: { result: Result, index: number })
		local leftOrder, rightOrder = left.result.order or 0, right.result.order or 0
		return if leftOrder == rightOrder then left.index < right.index else leftOrder < rightOrder
	end)

	for _, entry in ordered do
		local result = entry.result

		if result.report.failed then
			continue
		end

		for _, record in result.records or {} do
			-- A record that names its repository the way a card did before a
			-- move still finds that card.
			identifyRef(doc, record.ref)
			local repository = if record.repo then findRepository(doc, record.repo) else nil
			record.repo = if repository then repository.name else record.repo

			local existing: Item? = if record.shouldFindFallbackFirst and record.findFallback
				then record.findFallback(doc)
				else nil

			if not existing then
				for _, item in doc.nodes do
					if item.type == "task" and findSameRef(item, record.ref) then
						existing = item
						break
					end
				end
			end

			if not existing and not record.shouldFindFallbackFirst and record.findFallback then
				existing = record.findFallback(doc)
			end

			if not existing and record.isUpdateOnly then
				continue
			end

			local item = existing
				or createItem(doc, record.label, record.repo, record.createStatus or "todo", record.createWho)

			if not record.isUncounted then
				if existing then
					result.report.updated += 1
				else
					result.report.added += 1
				end
			end

			if not existing or record.setLabelOnUpdate ~= false then
				item.data.label = record.label
			end

			if record.repo and (not existing or record.setRepoOnUpdate ~= false) then
				item.data.repo = record.repo
			end

			if record.itemKind and (not record.keepPullKind or not findRef(item, "pull")) then
				item.data.itemKind = record.itemKind
			end

			if record.status then
				item.data.status, item.data.who = record.status, record.who
				item.data.deferredByClosedPull = nil
			end

			if record.updateStatus then
				record.updateStatus(item)
			end

			setRef(item, record.ref)

			if record.mentionText then
				table.insert(pendingLinks, { record = record, item = item, report = result.report })
			end
		end
	end

	linkMentions(doc, pendingLinks)
	return { sources = reports }
end

return placeRecords
