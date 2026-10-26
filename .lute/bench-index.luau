--[[
	Compares opening a canvas and answering `orion next` from its SQLite index
	with reading every file. Writes a generated canvas of cards in groups,
	chained by links, to a scratch folder, then times each side several times
	and prints the medians in milliseconds.

	lute run bench-index [--cards <count>] [--runs <count>]
]]
local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")
local time = require("@std/time")

local decodeDocObject = require("@cli/store/decodeDocObject")
local derive = require("@cli/graph/derive")
local isWork = require("@cli/graph/isWork")
local joinCanvasFiles = require("@cli/store/joinCanvasFiles")
local openCanvasIndex = require("@cli/store/openCanvasIndex")
local readCanvasFolder = require("@cli/store/readCanvasFolder")
local readCanvasIndex = require("@cli/store/readCanvasIndex")
local runScript = require("@cli/runScript")
local sortTasks = require("@cli/cli/sortTasks")
local testing = require("@cli/testing")
local writeDoc = require("@cli/store/writeDoc")

local GROUP_SIZE = 25
local NOW = "2026-10-18T00:00:00Z"

local function getOption(name: string, default: number): number
	for index, argument in process.args do
		if argument == `--{name}` then
			return assert(tonumber(process.args[index + 1]), `--{name} takes a number`)
		end
	end

	return default
end

local function createCanvas(dir: string, cards: number)
	local nodes = {}
	local links = {}

	for group = 1, math.ceil(cards / GROUP_SIZE) do
		table.insert(nodes, testing.group(`group-{group}`, `Group {group}`))
	end

	for card = 1, cards do
		local status = if card % 4 == 0 then "done" elseif card % 7 == 0 then "active" else "todo"
		local note = json.object({ note = string.rep(`Notes for card {card}. `, 6) })
		local parent = `group-{math.ceil(card / GROUP_SIZE)}`
		table.insert(nodes, testing.task(`card-{card}`, `Card {card}`, status, parent, note))

		if card % GROUP_SIZE ~= 1 then
			table.insert(links, { `card-{card - 1}`, `card-{card}` })
		end
	end

	writeDoc(dir, testing.createDoc(nodes, links))
end

-- Opens the canvas and answers `orion next` the way the command does.
local function answerNext(document: json.Object): number
	local doc = decodeDocObject(document)
	local derived = derive(doc, NOW)
	local items = sortTasks(doc, derived, function(item)
		local status = derived.status[item.id]
		return isWork(item) and (status == "ready" or status == "active" or status == "review")
	end)

	return #items
end

local function measure(runs: number, run: () -> ()): number
	local times: { number } = {}

	for _ = 1, runs do
		local started = time.now()
		run()
		table.insert(times, time.since(started) * 1000)
	end

	table.sort(times)
	return times[math.ceil(#times / 2)]
end

runScript(function()
	local cards = getOption("cards", 5000)
	local runs = getOption("runs", 7)
	local dir = tostring(path.join(system.tmpdir(), `orion-bench-index-{process.pid()}`))
	createCanvas(dir, cards)

	local ready = 0
	local fromFiles = measure(runs, function()
		ready = answerNext(joinCanvasFiles(readCanvasFolder(dir)))
	end)
	local fromNewIndex = measure(runs, function()
		openCanvasIndex(dir, true)
		answerNext((assert(readCanvasIndex(dir, false))).document)
	end)
	local fromIndex = measure(runs, function()
		assert(answerNext((assert(readCanvasIndex(dir, false))).document) == ready, "the index answered differently")
	end)

	print(`{cards} cards, {ready} ready, median of {runs} runs`)
	print(`  reading every file    {math.floor(fromFiles)} ms`)
	print(`  building the index    {math.floor(fromNewIndex)} ms`)
	print(`  from the index        {math.floor(fromIndex)} ms`)

	fs.removeDirectory(dir, { recursive = true })
end)
