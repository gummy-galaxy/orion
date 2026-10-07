local graph = require("@root/graph")
local types = require("@root/types")

type Doc = types.Doc
type Item = types.Item

export type Candidate = { id: string, score: number }

local STOP =
	{ the = true, ["and"] = true, ["for"] = true, with = true, from = true, into = true, add = true, use = true }
local match = {}

local function words(value: string): { [string]: boolean }
	local result: { [string]: boolean } = {}

	for word in value:lower():gmatch("[a-z0-9]+") do
		if #word >= 3 and not STOP[word] then
			result[word] = true
		end
	end

	return result
end

local function overlap(firstText: string, secondText: string): number
	local left, right = words(firstText), words(secondText)
	local intersection, union = 0, 0

	for word in left do
		union += 1

		if right[word] then
			intersection += 1
		end
	end

	for word in right do
		if not left[word] then
			union += 1
		end
	end

	return if union == 0 then 0 else intersection / union
end

match.overlap = overlap
match.words = words

local function stringField(item: Item, key: string): string?
	local value = item.data[key]
	return if type(value) == "string" then value else nil
end

function match.candidates(doc: Doc, title: string, owner: string, name: string): { Candidate }
	local candidates: { Candidate } = {}

	for _, item in doc.nodes do
		if item.type ~= "task" or graph.isNote(item) or item.data.pr ~= nil or item.data.status == "done" then
			continue
		end

		local repository = stringField(item, "repo")
		local agreement = if repository == nil
			then 0.3
			elseif
				(repository:lower() == name:lower() and owner:lower() == doc.settings.githubOwner:lower())
				or repository:lower() == string.lower(`{owner}/{name}`)
			then 1
			else 0
		local score = 0.65 * overlap(title, `{graph.label(item)} {stringField(item, "note") or ""}`) + 0.35 * agreement

		if score >= 0.2 then
			table.insert(candidates, { id = item.id, score = math.floor(score * 100 + 0.5) / 100 })
		end
	end

	table.sort(candidates, function(firstCandidate: Candidate, secondCandidate: Candidate)
		return if firstCandidate.score == secondCandidate.score
			then firstCandidate.id < secondCandidate.id
			else firstCandidate.score > secondCandidate.score
	end)

	while #candidates > 3 do
		table.remove(candidates)
	end

	return candidates
end

return table.freeze(match)
