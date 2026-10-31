local fs = require("@std/fs")
local json = require("@std/json")
local test = require("@std/test")

local startSessionAsync = require("@root/sources/sessions/startSessionAsync")
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

test.case("with no folder, the prompt says where the work is", function(assert)
	local item = testing.task("fix", "Fix", "active", nil, { repo = "owner/repo" })
	local doc = testing.createDoc({ item })
	local function run()
		return testing.result(false, "")
	end

	local start = startSessionAsync(doc, item, "work", run, {}, false)

	assert.eq(start.place, "none")
	assert.eq(start.url:find("folder=", 1, true), nil)
	assert.strContains(start.url, "The%20work%20is%20in%20owner%2Frepo")
end)

test.case("a preset that doesn't fit the card fails plainly", function(assert)
	local item = testing.task("fix", "Fix", "active", nil, { repo = "owner/repo" })
	local function run()
		return testing.result(false, "")
	end

	local _, unfit = pcall(startSessionAsync, testing.createDoc({ item }), item, "resolve-conflicts", run, {}, false)
	assert.strContains(tostring(unfit), "doesn't fit")
end)
