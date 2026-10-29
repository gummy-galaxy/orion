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
type StartOptions = sessionTypes.StartOptions

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
	it, the agent that would run, and the folder it would start in. `problem`
	says what's in the way when one of those is missing.
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

	local options: StartOptions = { presets = fitting }

	for _, source in doc.settings.sources do
		local succeeded, adapter = pcall(getAdapter, source.kind)

		if succeeded and adapter.agent and adapter.agent.getStartUrl then
			options.agent = adapter.agent.name
			options.source = source
			break
		end
	end

	local repo = item.data.repo
	local branch = getBranch(item)
	options.branch = branch

	if #fitting == 0 then
		options.problem = "Only cards can start sessions."
	elseif not options.source then
		options.problem = "Add an agent source first, such as with orion source add claude."
	elseif type(repo) ~= "string" or not branch then
		options.problem = "This card needs a branch or pull request to start from."
	else
		options.folder = findStartFolderAsync(doc, item, repo, branch, run, commands)

		if not options.folder then
			options.problem = `No folder has {branch} checked out. Check it out, then try again.`
		end
	end

	return options
end

return getStartOptionsAsync
