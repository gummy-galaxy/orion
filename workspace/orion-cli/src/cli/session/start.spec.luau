local fs = require("@std/fs")
local json = require("@std/json")
local test = require("@std/test")

local testing = require("@root/testing")
local writeDoc = require("@root/store/writeDoc")

-- A canvas with a Claude Code source and a card whose last session ran in a
-- folder that still has agent/fix checked out.
local function setUp(name: string): (string, string)
	local dir = testing.directory(name)
	local folder = testing.directory(`{name}-checkout`)
	fs.createDirectory(folder, { makeParents = true })
	local doc = testing.createDoc({
		testing.task("fix", "Fix the flaky test", "active", nil, {
			repo = "owner/repo",
			refs = {
				json.object({ source = "branch", kind = "branch", key = "owner/repo@agent/fix" }),
				json.object({
					source = "claude",
					kind = "session",
					key = "Fix",
					details = json.object({ cwd = folder }),
				}),
			},
		}),
	})
	table.insert(doc.settings.sources, { id = "claude", kind = "claude" })
	writeDoc(dir, doc)
	return dir, folder
end

test.case("session start opens Claude Desktop on the card's folder", function(assert)
	local dir, folder = setUp("session-start")
	local opened: { string }? = nil
	local function run(argv: { string })
		if argv[1] ~= "git" then
			opened = argv
		end

		return testing.result(true, "agent/fix\n")
	end

	local output = json.asObject(json.deserialize(testing.run(dir, { "session", "start", "fix", "--json" }, run)))

	assert.eq(output and output.preset, "work")
	assert.eq(output and output.folder, folder)
	assert.eq(output and output.opened, true)
	assert.eq(opened and opened[#opened], output and output.url)
	fs.removeDirectory(folder, { recursive = true })
end)

test.case("session start --dry-run prints the link without opening it", function(assert)
	local dir, folder = setUp("session-start-dry")
	local opened = false
	local function run(argv: { string })
		opened = opened or argv[1] ~= "git"
		return testing.result(true, "agent/fix\n")
	end

	local output = testing.run(dir, { "session", "start", "fix", "--dry-run" }, run)

	assert.strContains(output, "claude://code/new?folder=")
	assert.eq(opened, false)
	fs.removeDirectory(folder, { recursive = true })
end)

test.case("session presets lists what fits and where it starts", function(assert)
	local dir, folder = setUp("session-presets")
	local function run()
		return testing.result(true, "agent/fix\n")
	end

	local output = testing.run(dir, { "session", "presets", "fix" }, run)

	assert.strContains(output, "work: Work on this card")
	assert.strContains(output, `Starts Claude Code in {folder}.`)
	assert.eq(output:find("resolve-conflicts", 1, true), nil)
	fs.removeDirectory(folder, { recursive = true })
end)
