local json = require("@std/json")
local process = require("@std/process")
local test = require("@std/test")

local readLog = require("@root/log/readLog")
local store = require("@root/store")
local testing = require("@root/testing")

local NOW = "2026-10-12T18:00:00Z"
-- Entries without --agent are by the user running the CLI, which is $USER when it is set.
local PERSON = process.env.USER or "person"

local function createCanvas(name: string): string
	local dir = testing.directory(name)
	store.write(
		dir,
		testing.createDoc({
			testing.group("release", "Release"),
			testing.task("moments", "Moments", "active", "release"),
			testing.task("avatars", "Avatars", "todo", "release"),
		})
	)
	return dir
end

test.case("log add attaches one entry to several cards without touching the canvas revision", function(assert)
	local dir = createCanvas("log-attach")
	local revision = store.load(dir).revision

	testing.run(dir, { "log", "add", "Tested", "Moments", "--card", "moments,avatars" }, nil, NOW)

	local entries = readLog(dir)
	assert.eq(#entries, 1)
	assert.eq(entries[1].id, "log-1")
	assert.eq(entries[1].text, "Tested Moments")
	assert.eq(entries[1].time, NOW)
	assert.eq(entries[1].author.kind, "person")
	assert.eq(#entries[1].targets, 2)
	assert.eq(entries[1].targets[1].id, "moments")
	assert.eq(entries[1].targets[2].id, "avatars")
	assert.eq(store.load(dir).revision, revision)
end)

test.case("log entries are appended as agents or people and never edited", function(assert)
	local dir = createCanvas("log-authors")

	testing.run(dir, { "log", "add", "First" }, nil, NOW)
	testing.run(
		dir,
		{ "log", "add", "Correction:", "the", "first", "entry", "was", "wrong", "--agent", "claude" },
		nil,
		NOW
	)

	local entries = readLog(dir)
	assert.eq(#entries, 2)
	assert.eq(entries[1].text, "First")
	assert.eq(#entries[1].targets, 0)
	assert.eq(entries[2].author.kind, "agent")
	assert.eq(entries[2].author.name, "claude")
	assert.eq(entries[2].id, "log-2")
end)

test.case("log list prints newest first and filters to one card", function(assert)
	local dir = createCanvas("log-list")

	testing.run(dir, { "log", "add", "Moments", "passed", "--card", "moments" }, nil, NOW)
	testing.run(dir, { "log", "add", "Avatars", "next", "--card", "avatars", "--agent", "claude" }, nil, NOW)

	local all = testing.run(dir, { "log", "list" })
	assert.eq(
		all,
		"log-2  2026-10-12T18:00:00Z  claude (agent)  avatars  Avatars next\n"
			.. `log-1  2026-10-12T18:00:00Z  {PERSON}  moments  Moments passed`
	)

	local onlyMoments = testing.run(dir, { "log", "list", "--card", "moments" })
	assert.eq(onlyMoments, `log-1  2026-10-12T18:00:00Z  {PERSON}  moments  Moments passed`)
end)

test.case("log list --json returns entries with their author and targets", function(assert)
	local dir = createCanvas("log-json")
	testing.run(dir, { "log", "add", "Ready", "to", "merge", "--card", "moments", "--agent", "claude" }, nil, NOW)

	local value = json.asArray(json.deserialize(testing.run(dir, { "log", "list", "--json" })) :: json.Value)
	assert.eq(value ~= nil, true)
	local entry = json.asObject((value :: json.Array)[1]) :: json.Object
	assert.eq(entry.text, "Ready to merge")
	assert.eq((json.asObject(entry.author) :: json.Object).kind, "agent")
	assert.eq((json.asArray(entry.targets) :: json.Array)[1] ~= nil, true)
end)

test.case("log add refuses empty text, groups, and unknown cards without writing", function(assert)
	local dir = createCanvas("log-refuse")

	assert.throwsWith("log text must not be empty", function()
		testing.run(dir, { "log", "add", "  ", "--card", "moments" }, nil, NOW)
	end)
	assert.throwsWith("log against a card", function()
		testing.run(dir, { "log", "add", "Nope", "--card", "release" }, nil, NOW)
	end)
	assert.throwsWith('no item with id "missing"', function()
		testing.run(dir, { "log", "add", "Nope", "--card", "missing" }, nil, NOW)
	end)

	assert.eq(#readLog(dir), 0)
end)

test.case("card show lists the card's most recent entries, newest first", function(assert)
	local dir = createCanvas("card-show")

	for index = 1, 7 do
		testing.run(dir, { "log", "add", `Update {index}`, "--card", "moments" }, nil, NOW)
	end
	testing.run(dir, { "log", "add", "Elsewhere", "--card", "avatars" }, nil, NOW)

	local output = testing.run(dir, { "card", "show", "moments" })
	assert.strContains(output, "Moments")
	assert.strContains(output, `Log\n  log-7  2026-10-12T18:00:00Z  {PERSON}  Update 7\n`)
	assert.strContains(output, `  log-3  2026-10-12T18:00:00Z  {PERSON}  Update 3`)
	assert.strNotContains(output, "log-2 ")
	assert.strNotContains(output, "Elsewhere")

	local limited = testing.run(dir, { "card", "show", "moments", "--limit", "1" })
	assert.strContains(limited, "  log-7  ")
	assert.strNotContains(limited, "log-6")
end)

test.case("card show without entries says so and refuses groups", function(assert)
	local dir = createCanvas("card-show-empty")

	assert.strContains(testing.run(dir, { "card", "show", "avatars" }), "No entries yet.")
	assert.throwsWith("use orion group set", function()
		testing.run(dir, { "card", "show", "release" })
	end)
end)
