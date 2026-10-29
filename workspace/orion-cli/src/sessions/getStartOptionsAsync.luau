local findRef = require("@root/refs/findRef")
local findStartFolderAsync = require("@root/sessions/findStartFolderAsync")
local getAdapter = require("@root/adapters/getAdapter")
local presets = require("@root/sessions/presets")
local sessionTypes = require("@root/sessions/types")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type Doc = types.Doc
type Item = types.Item
type Preset = sessionTypes.Preset
type Source = types.Source
type StartOptions = sessionTypes.StartOptions

-- The agent that starts sessions when the canvas has no agent source of its
-- own. Its sessions reach the card once someone adds the source.
local DEFAULT_AGENT_SOURCE: Source = { id = "claude", kind = "claude" }

-- The branch the card's work is on, from its branch ref or its pull request.
local function getBranch(item: Item): string?
	local branchRef = findRef(item, "branch")
	local branch = if branchRef then branchRef.key:match("@(.+)$") else nil
	local pull = findRef(item, "pull")
	local pullBranch = if pull and pull.details then pull.details.branch else nil

	return branch or (if type(pullBranch) == "string" then pullBranch else nil)
end

--[[
	What starting an agent session from the card would do: the presets that fit
	it, the agent that would run, and where it would start. A session can start
	from any card, so `problem` is set only for one that isn't a card.
]]
local function getStartOptionsAsync(
	doc: Doc,
	item: Item,
	run: CommandRunner,
	commands: { [string]: { string } }
): StartOptions
	local fitting: { Preset } = {}

	for _, preset in presets do
		if preset.appliesTo(item) then
			table.insert(fitting, preset)
		end
	end

	local source = DEFAULT_AGENT_SOURCE
	local attaches = false

	for _, candidate in doc.settings.sources do
		local succeeded, adapter = pcall(getAdapter, candidate.kind)

		if succeeded and adapter.agent and adapter.agent.getStartUrl then
			source = candidate
			attaches = true
			break
		end
	end

	local repo = if type(item.data.repo) == "string" and item.data.repo ~= "" then item.data.repo else nil
	local branch = getBranch(item)
	local folder, place = nil, "none"

	if #fitting > 0 then
		folder, place = findStartFolderAsync(doc, item, repo, branch, run, commands)
	end

	return {
		presets = fitting,
		agent = assert(getAdapter(source.kind).agent).name,
		source = source,
		attaches = attaches,
		repo = repo,
		branch = branch,
		place = place,
		folder = folder,
		problem = if #fitting == 0 then "Only cards can start sessions." else nil,
	}
end

return getStartOptionsAsync
