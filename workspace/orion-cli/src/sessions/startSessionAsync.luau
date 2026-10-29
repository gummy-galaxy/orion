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

--[[
	Starts an agent session from the card with the preset: builds the agent's
	link for the card's folder and prompt and, unless `shouldOpen` is false,
	hands it to the app that opens it. Fails with a message a person can act
	on when the card can't start one.
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

	local source = assert(options.source)
	local folder = assert(options.folder)
	local agent = assert(getAdapter(source.kind).agent)
	local getStartUrl = assert(agent.getStartUrl)
	local url = getStartUrl(source, { cwd = folder, prompt = preset.buildPrompt(item, assert(options.branch)) })

	if shouldOpen then
		openUrlAsync(url, run)
	end

	return { agent = agent.name, folder = folder, preset = preset, url = url }
end

return startSessionAsync
