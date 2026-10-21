local json = require("@std/json")
local test = require("@std/test")

local buildTools = require("@root/cli/mcp/catalog/buildTools")
local cli = require("@root/cli")
local getToolArgv = require("@root/cli/mcp/catalog/getToolArgv")
local testing = require("@root/testing")

local TOOLS = buildTools(cli.describe())

local function argv(name: string, arguments: { [string]: any }): string
	return table.concat(getToolArgv(TOOLS, name, json.object(arguments)), " ")
end

test.case("tool arguments map onto the command each tool runs", function(assert)
	assert.eq(argv("orion_node_show", { id = "ci" }), "node show ci --json")
	assert.eq(argv("orion_node_move", { ids = { "ci" }, top = true }), "node move ci --top --json")
	assert.eq(
		argv("orion_node_move", { ids = { "ci", "pub" }, to = "release" }),
		"node move ci pub --to release --json"
	)
	assert.throwsWith("missing where", function()
		argv("orion_node_query", {})
	end)
	assert.throwsWith("missing id", function()
		argv("orion_node_show", {})
	end)
end)

test.case("each read command has its own tool", function(assert)
	assert.eq(argv("orion_card_list", { group = "ws", all = true }), "card list --group ws --all --json")
	assert.eq(argv("orion_next", {}), "next --json")
	assert.eq(argv("orion_group_list", {}), "group list --json")
	assert.eq(argv("orion_source_matches", { canvas = "focus" }), "source matches --canvas focus --json")
	assert.throwsWith("unknown argument: id", function()
		argv("orion_card_list", { id = "ci" })
	end)
end)

test.case("orion_node_find runs node find with its text, limit, and canvas scope", function(assert)
	assert.eq(argv("orion_node_find", { text = "release notes" }), "node find release notes --json")
	assert.eq(
		argv("orion_node_find", { text = "release", limit = 5, allCanvases = true }),
		"node find release --limit 5 --all-canvases --json"
	)
	assert.throwsWith("missing text", function()
		argv("orion_node_find", {})
	end)
end)

test.case("group create takes a label and an optional parent", function(assert)
	assert.eq(argv("orion_group_create", { label = "Week 1" }), "group create Week 1 --json")
	assert.eq(
		argv("orion_group_create", { label = "Monday", ["in"] = "week-1" }),
		"group create Monday --in week-1 --json"
	)
end)

test.case("group and ref tools run their subcommands", function(assert)
	assert.eq(
		argv("orion_group_add", { label = "Ship", items = { "ci", "pub" } }),
		"group add Ship --items ci,pub --json"
	)
	assert.eq(argv("orion_group_remove", { ids = { "ws" }, dryRun = true }), "group remove ws --dry-run --json")
	assert.eq(argv("orion_ref_remove", { id = "ci", ref = "owner/name#1" }), "ref remove ci owner/name#1 --json")
	assert.throwsWith("missing items", function()
		argv("orion_group_add", { label = "Ship", items = {} })
	end)
end)

test.case("batch and link tools pass ids, chains, and revision guards through", function(assert)
	assert.eq(
		argv("orion_node_remove", { ids = { "a", "b" }, reconnect = true, ifRevision = 12 }),
		"node remove a b --if-revision 12 --reconnect --json"
	)
	assert.eq(
		argv("orion_card_done", { where = 'label ~ "ship"', dryRun = true }),
		'card done --where label ~ "ship" --dry-run --json'
	)
	assert.eq(argv("orion_link_add", { from = "a", to = "b", next = { "c" } }), "link add a b c --json")
	assert.eq(
		argv("orion_link_insert", { id = "x", between = "a", target = { "b" } }),
		"link insert x b --between a --json"
	)
	assert.eq(
		argv("orion_group_set", { id = "g", label = "New", arrange = "custom" }),
		"group set g --label New --arrange custom --json"
	)
	assert.eq(argv("orion_group_set", { id = "g", color = "" }), "group set g --color  --json")
	assert.throwsWith("missing between", function()
		argv("orion_link_insert", { id = "x", target = { "b" } })
	end)
end)

test.case("orion_card_import passes each ref as a trailing positional", function(assert)
	assert.eq(
		argv("orion_card_import", {
			refs = { "https://github.com/vocksel/orion/issues/91", "jira:ABC-1" },
			group = "release",
			dryRun = true,
		}),
		"card import https://github.com/vocksel/orion/issues/91 jira:ABC-1 --group release --dry-run --json"
	)
	assert.throwsWith("refs must be a list of strings", function()
		argv("orion_card_import", { refs = { "" } })
	end)
	assert.throwsWith("unknown argument: stdin", function()
		argv("orion_card_import", { refs = { "jira:ABC-1" }, stdin = true })
	end)
end)

test.case("orion_apply passes the plan inline with its dry run and revision", function(assert)
	local steps = json.asArray(json.deserialize([=[[{"op":"addCard","label":"Ship"}]]=]) :: json.Value)
	assert.eq(
		argv("orion_apply", { plan = steps, dryRun = true, ifRevision = 4, canvas = "release" }),
		'apply --canvas release --plan [{"op":"addCard","label":"Ship"}] --dry-run --if-revision 4 --json'
	)
	assert.throwsWith("plan must be a list of objects", function()
		argv("orion_apply", { plan = {} })
	end)
	assert.throwsWith("plan must be a list of objects", function()
		argv("orion_apply", { plan = { "addCard" } })
	end)
end)

test.case("orion_suggestion_find takes no command to run", function(assert)
	assert.eq(
		argv("orion_suggestion_find", { scope = "all", dryRun = true, canvas = "release" }),
		"suggestion find --canvas release --scope all --dry-run --json"
	)
	assert.throwsWith("unknown argument: command", function()
		argv("orion_suggestion_find", { command = { "claude", "-p" } })
	end)
end)

test.case("tools reject arguments their schemas do not allow", function(assert)
	assert.throwsWith("unknown argument: colour", function()
		argv("orion_card_add", { label = "A", colour = "red" })
	end)
	assert.throwsWith("status must be one of: todo, active, review, blocked, deferred, done", function()
		argv("orion_card_add", { label = "A", status = "later" })
	end)
	assert.throwsWith("who must be one of: you, review, ci", function()
		argv("orion_card_add", { label = "A", who = "" })
	end)
	assert.throwsWith("unknown argument: pr", function()
		argv("orion_card_add", { label = "A", pr = 4 })
	end)
	assert.throwsWith("items must be a list of strings", function()
		argv("orion_group_add", { label = "G", items = { 1 } })
	end)
	assert.throwsWith("unknown argument: canvas", function()
		argv("orion_theme_list", { canvas = "focus" })
	end)
end)

test.case("mcp tool arguments run the existing command", function(assert)
	local dir = testing.createHarness("mcp-argv")
	local output: { string } = {}
	cli.execute(getToolArgv(TOOLS, "orion_card_add", json.object({ label = "From the catalog" })), {
		dataDir = dir,
		write = function(text)
			table.insert(output, text)
		end,
	})
	assert.strContains(table.concat(output, "\n"), "From the catalog")
end)

test.case("card set passes ref through as --ref and clears who with an empty value", function(assert)
	assert.eq(
		getToolArgv(TOOLS, "orion_card_set", json.object({ id = "pub", ref = "jira:ABC-1" })),
		{ "card", "set", "pub", "--ref", "jira:ABC-1", "--json" }
	)
	assert.eq(
		getToolArgv(TOOLS, "orion_card_set", json.object({ id = "pub", who = "" })),
		{ "card", "set", "pub", "--who", "", "--json" }
	)
	assert.eq(
		getToolArgv(TOOLS, "orion_card_add", json.object({ label = "Ingest", repo = "Roblox/avatar" })),
		{ "card", "add", "Ingest", "--repo", "Roblox/avatar", "--json" }
	)
end)

test.case("canvas tools map onto the canvas commands", function(assert)
	assert.eq(argv("orion_canvas_create", { label = "Focus areas" }), "canvas create --label Focus areas --json")
	assert.eq(
		argv("orion_canvas_create", { name = "focus", label = "Focus" }),
		"canvas create focus --label Focus --json"
	)
	assert.eq(argv("orion_canvas_rename", { name = "focus", label = "Focus" }), "canvas rename focus Focus --json")
	assert.eq(argv("orion_canvas_archive", { name = "focus" }), "canvas archive focus --json")
	assert.eq(argv("orion_canvas_restore", { name = "focus" }), "canvas restore focus --json")
	assert.eq(argv("orion_canvas_list", { archived = true }), "canvas list --archived --json")
	assert.throwsWith("missing name", function()
		argv("orion_canvas_archive", {})
	end)
end)

test.case("orion_reveal passes each id as a trailing positional and selectOnly as a flag", function(assert)
	assert.eq(argv("orion_reveal", { ids = { "ci", "pub" } }), "reveal ci pub --json")
	assert.eq(
		argv("orion_reveal", { ids = { "ci" }, selectOnly = true, canvas = "planning" }),
		"reveal ci --canvas planning --select-only --json"
	)
	assert.throwsWith("ids must be a list of strings", function()
		argv("orion_reveal", { ids = { "" } })
	end)
	assert.throwsWith("missing ids", function()
		argv("orion_reveal", {})
	end)
end)

test.case("log tools attach entries to cards and name the agent that wrote them", function(assert)
	assert.eq(
		argv("orion_log_add", { text = "Tested Moments", card = { "moments", "avatars" }, agent = "claude" }),
		"log add Tested Moments --card moments,avatars --agent claude --json"
	)
	assert.eq(
		argv("orion_log_add", { text = "Canvas-wide", agent = "claude" }),
		"log add Canvas-wide --agent claude --json"
	)
	assert.eq(argv("orion_log_list", { card = "moments", limit = 2 }), "log list --card moments --limit 2 --json")
	assert.eq(argv("orion_card_timeline", { id = "moments", limit = 3 }), "card timeline moments --limit 3 --json")
	assert.throwsWith("missing agent", function()
		argv("orion_log_add", { text = "No name" })
	end)
end)

test.case("layout tools map onto group tidy and canvas check", function(assert)
	assert.eq(
		getToolArgv(
			TOOLS,
			"orion_group_tidy",
			json.object({ ids = { "ws", "release" }, dryRun = true, canvas = "focus" })
		),
		{ "group", "tidy", "ws", "release", "--canvas", "focus", "--dry-run", "--json" }
	)
	assert.eq(
		getToolArgv(TOOLS, "orion_group_tidy", json.object({ where = 'label ~ "release"', ifRevision = 0 })),
		{ "group", "tidy", "--where", 'label ~ "release"', "--if-revision", "0", "--json" }
	)
	assert.eq(getToolArgv(TOOLS, "orion_canvas_check", json.object({})), { "canvas", "check", "--json" })
	assert.eq(
		getToolArgv(TOOLS, "orion_canvas_check", json.object({ group = "ws", canvas = "focus" })),
		{ "canvas", "check", "--canvas", "focus", "--group", "ws", "--json" }
	)
	assert.throwsWith("ifRevision must be a nonnegative integer", function()
		argv("orion_group_tidy", { ids = { "ws" }, ifRevision = -1 })
	end)
	assert.throwsWith("ids must be a list of strings", function()
		argv("orion_group_tidy", { ids = { "" } })
	end)
	assert.throwsWith("unknown argument: deep", function()
		argv("orion_group_tidy", { ids = { "ws" }, deep = true })
	end)
end)
