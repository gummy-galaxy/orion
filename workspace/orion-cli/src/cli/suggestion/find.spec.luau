local json = require("@std/json")
local test = require("@std/test")

local cli = require("@root/cli")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local loadDoc = require("@root/store/loadDoc")
local testing = require("@root/testing")
local writeDoc = require("@root/store/writeDoc")

test.case("--command receives bounded context on stdin", function(assert)
	local dir = testing.directory("suggest-command")
	local doc = testing.createDoc({
		testing.task(
			"a",
			"First work",
			"todo",
			nil,
			json.object({
				repo = "vocksel/app",
				refs = { { source = "hop", kind = "branch", key = "vocksel/app@same" } },
			})
		),
		testing.task(
			"b",
			"Second work",
			"todo",
			nil,
			json.object({
				repo = "vocksel/app",
				refs = { { source = "hop", kind = "branch", key = "vocksel/app@same" } },
			})
		),
	})
	writeDoc(dir, doc)
	local output = ""
	cli.execute({ "suggestion", "find", "--command", [[ ["custom-agent","--json"] ]], "--dry-run", "--json" }, {
		dataDir = dir,
		write = function(value)
			output = value
		end,

		runner = function(argv, stdin)
			assert.eq(table.concat(argv, " "), "custom-agent --json")
			assert.strContains(stdin or "", "singletons")
			return testing.result(true, [[{"groups":[{"title":"Avatar work","members":["a","b"]}]}]])
		end,
	})
	local result = json.asObject(json.deserialize(output) :: json.Value)
	local groups = if result then json.asArray(result.groups) else nil
	local first = if groups then json.asObject(groups[1]) else nil
	assert.eq(first and first.source, "agent")
	assert.eq(loadDoc(dir).revision, 0)
end)

test.case("--command must be a JSON array of strings", function(assert)
	local _, run = testing.createHarness("suggest-bad-command")
	assert.throwsWith("--command must be a nonempty JSON array", function()
		run({ "suggestion", "find", "--command", "claude" })
	end)
end)

test.case("suggest reads and saves only the selected workspace", function(assert)
	local root, run = testing.createHarness("suggest-workspace")
	run({ "canvas", "create", "roblox" })
	local dir = getWorkspaceDir(root, "roblox")
	writeDoc(
		dir,
		testing.createDoc({
			testing.task(
				"a",
				"First work",
				"todo",
				nil,
				json.object({
					repo = "vocksel/app",
					refs = { { source = "hop", kind = "branch", key = "vocksel/app@same" } },
				})
			),
			testing.task(
				"b",
				"Second work",
				"todo",
				nil,
				json.object({
					repo = "vocksel/app",
					refs = { { source = "hop", kind = "branch", key = "vocksel/app@same" } },
				})
			),
		})
	)
	assert.strContains(run({ "suggestion", "find", "--dry-run" }), "0 group suggestions")
	assert.strContains(run({ "suggestion", "find", "--canvas", "roblox" }), "1 group suggestions")
	assert.eq(loadDoc(root).suggestions, nil)
	local saved =
		json.asObject(json.deserialize(run({ "suggestion", "list", "--json", "--canvas", "roblox" })) :: json.Value)
	assert.eq(saved and #(json.asArray(saved.groups) or {}), 1)
end)
