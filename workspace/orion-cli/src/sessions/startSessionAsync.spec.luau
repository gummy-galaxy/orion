local fs = require("@std/fs")
local json = require("@std/json")
local test = require("@std/test")

local startSessionAsync = require("@root/sessions/startSessionAsync")
local testing = require("@root/testing")
local types = require("@root/types")

type Item = types.Item

local function card(folder: string, readiness: string?): Item
	return testing.task("fix", "Fix", "active", nil, {
		repo = "owner/repo",
		refs = {
			json.object({
				source = "github",
				kind = "pull",
				key = "owner/repo#12",
				readiness = readiness,
				details = json.object({ branch = "agent/fix" }),
			}),
			json.object({
				source = "claude",
				kind = "session",
				key = "Fix",
				details = json.object({ cwd = folder }),
			}),
		},
	})
end

test.case("starting a session opens the agent's link for the card", function(assert)
	local folder = testing.directory("start-session-open")
	fs.createDirectory(folder, { makeParents = true })
	local item = card(folder, "conflict")
	local doc = testing.createDoc({ item })
	table.insert(doc.settings.sources, { id = "claude", kind = "claude" })
	local opened: { string }? = nil
	local function run(argv: { string })
		if argv[1] ~= "git" then
			opened = argv
		end

		return testing.result(true, "agent/fix\n")
	end

	local start = startSessionAsync(doc, item, "resolve-conflicts", run, {}, true)

	assert.eq(start.agent, "Claude Code")
	assert.eq(start.folder, folder)
	assert.eq(start.preset.id, "resolve-conflicts")
	assert.strContains(start.url, "claude://code/new?folder=")
	assert.strContains(start.url, "has%20merge%20conflicts")
	assert.eq(opened and opened[#opened], start.url)
	fs.removeDirectory(folder, { recursive = true })
end)

test.case("a preset that doesn't fit, or a card that can't start, fails plainly", function(assert)
	local folder = testing.directory("start-session-refuse")
	fs.createDirectory(folder, { makeParents = true })
	local item = card(folder)
	local doc = testing.createDoc({ item })
	local function run()
		return testing.result(true, "agent/fix\n")
	end

	local _, noAgent = pcall(startSessionAsync, doc, item, "work", run, {}, false)
	assert.strContains(tostring(noAgent), "agent source")

	table.insert(doc.settings.sources, { id = "claude", kind = "claude" })
	local _, unfit = pcall(startSessionAsync, doc, item, "resolve-conflicts", run, {}, false)
	assert.strContains(tostring(unfit), "doesn't fit")
	fs.removeDirectory(folder, { recursive = true })
end)
