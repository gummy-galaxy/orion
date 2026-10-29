local getAdapter = require("@root/adapters/getAdapter")
local getStartOptionsAsync = require("@root/sessions/getStartOptionsAsync")
local openUrlAsync = require("@root/platform/openUrlAsync")
local sessionTypes = require("@root/sessions/types")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type Doc = types.Doc
type Item = types.Item
type Preset = sessionTypes.Preset
type Start = sessionTypes.Start
type StartOptions = sessionTypes.StartOptions

-- Tells the agent where it's starting and what to set up before the work.
local function describePlace(options: StartOptions): string?
	local branch = options.branch

	if options.place == "checkout" then
		return `This folder has {branch} checked out.`
	elseif options.place == "clone" then
		local target = if branch then branch else "a new branch for this card"
		return `This is the main clone of {options.repo}. Make a worktree for {target} first, and work there.`
	elseif options.repo then
		local onBranch = if branch then ` on {branch}` else ""
		return `The work is in {options.repo}{onBranch}. Find or clone it, make a worktree for the work, and work there.`
	end

	return nil
end

--[[
	Starts an agent session from the card with the preset: builds the agent's
	link with the preset's prompt, starting where the card's work is, and,
	unless `shouldOpen` is false, hands it to the app that opens it. Fails with
	a message a person can act on when the preset doesn't fit the card.
]]
local function startSessionAsync(
	doc: Doc,
	item: Item,
	presetId: string,
	run: CommandRunner,
	commands: { [string]: { string } },
	shouldOpen: boolean
): Start
	local options = getStartOptionsAsync(doc, item, run, commands)
	local preset: Preset? = nil

	for _, candidate in options.presets do
		if candidate.id == presetId then
			preset = candidate
		end
	end

	if options.problem then
		error(options.problem, 0)
	end

	if not preset then
		error(`The {presetId} preset doesn't fit this card.`, 0)
	end

	local parts = { preset.buildPrompt(item, options.branch) }
	local place = describePlace(options)

	if place then
		table.insert(parts, place)
	end

	local agent = assert(getAdapter(options.source.kind).agent)
	local getStartUrl = assert(agent.getStartUrl)
	local url = getStartUrl(options.source, { cwd = options.folder, prompt = table.concat(parts, "\n\n") })

	if shouldOpen then
		openUrlAsync(url, run)
	end

	return { agent = agent.name, place = options.place, folder = options.folder, preset = preset, url = url }
end

return startSessionAsync
