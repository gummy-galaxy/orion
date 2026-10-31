local findRef = require("@root/canvas/refs/findRef")
local getRefs = require("@root/canvas/refs/getRefs")
local sessionTypes = require("@root/sources/sessions/types")
local types = require("@root/types")

type Item = types.Item
type Preset = sessionTypes.Preset

local function getText(value: unknown): string?
	return if type(value) == "string" and value ~= "" then value else nil
end

local function isConflicting(item: Item): boolean
	local pull = findRef(item, "pull")
	return pull ~= nil and pull.readiness == "conflict" and not pull.isDone
end

local function buildWorkPrompt(item: Item): string
	local lines = { `Work on this card from Orion: {getText(item.data.label) or "Untitled"}` }
	local note = getText(item.data.note)

	if note then
		table.insert(lines, "")
		table.insert(lines, note)
	end

	local links: { string } = {}

	for _, ref in getRefs(item) do
		if ref.kind ~= "session" then
			table.insert(links, `- {ref.url or ref.key}`)
		end
	end

	if #links > 0 then
		table.insert(lines, "")
		table.insert(lines, "Linked work:")

		for _, link in links do
			table.insert(lines, link)
		end
	end

	return table.concat(lines, "\n")
end

local function buildResolvePrompt(item: Item, branch: string?): string
	local pull = findRef(item, "pull")
	local name = if pull then pull.url or pull.key else "This pull request"

	return table.concat({
		`{name} has merge conflicts with its base branch.`,
		`Merge the latest base branch into {branch or "its branch"}, without rebasing or force-pushing.`,
		"Resolve each conflict so both sides' changes still hold, run the project's checks, then commit and push.",
		"If a conflict needs a decision the code can't settle, stop and ask.",
	}, " ")
end

-- The presets a card can start a session with, in the order the app offers
-- them.
local presets: { Preset } = {
	{
		id = "work",
		label = "Work on this card",
		appliesTo = function(item)
			return item.type == "task"
		end,
		buildPrompt = buildWorkPrompt,
	},
	{
		id = "resolve-conflicts",
		label = "Resolve conflicts",
		appliesTo = isConflicting,
		buildPrompt = buildResolvePrompt,
	},
}

return table.freeze(presets)
