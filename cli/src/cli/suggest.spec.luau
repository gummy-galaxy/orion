local json = require("@std/json")
local test = require("@std/test")

local cli = require("@root/cli")
local store = require("@root/store")
local testing = require("@root/testing")

test.case("configured agent command receives bounded context on stdin", function(assert)
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
	doc.raw = json.object({ settings = json.object({ agent = "claude", agentCommand = { "custom-agent", "--json" } }) })
	store.write(dir, doc)
	local output = ""
	cli.execute({ "suggest", "--dry-run", "--json" }, {
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
	assert.eq(store.load(dir).revision, 0)
end)

test.case("suggest reads and saves only the selected workspace", function(assert)
	local root, run = testing.createHarness("suggest-workspace")
	run({ "workspace", "create", "roblox" })
	local dir = store.getWorkspaceDir(root, "roblox")
	store.write(
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
	assert.strContains(run({ "suggest", "--dry-run" }), "0 group suggestions")
	assert.strContains(run({ "suggest", "--workspace", "roblox" }), "1 group suggestions")
	assert.eq(store.load(root).suggestions, nil)
	local saved =
		json.asObject(json.deserialize(run({ "suggestions", "--json", "--workspace", "roblox" })) :: json.Value)
	assert.eq(saved and #(json.asArray(saved.groups) or {}), 1)
end)
