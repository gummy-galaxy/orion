local json = require("@std/json")
local test = require("@std/test")

local cli = require("@root/cli")
local getToolArgv = require("@root/cli/mcp/catalog/getToolArgv")
local testing = require("@root/testing")

test.case("tool arguments map onto the command each tool runs", function(assert)
	assert.eq(
		table.concat(getToolArgv("orion_inspect", json.object({ view = "show", id = "ci" })), " "),
		"node show ci --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_move", json.object({ ids = { "ci" }, top = true })), " "),
		"node move ci --top --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_move", json.object({ ids = { "ci", "pub" }, group = "release" })), " "),
		"node move ci pub --to release --json"
	)
	assert.throwsWith("missing where", function()
		getToolArgv("orion_query", json.object({}))
	end)
	assert.throwsWith("missing id", function()
		getToolArgv("orion_inspect", json.object({ view = "show" }))
	end)
end)

test.case("orion_find runs node find with its text, limit, and canvas scope", function(assert)
	assert.eq(
		table.concat(getToolArgv("orion_find", json.object({ text = "release notes" })), " "),
		"node find release notes --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_find", json.object({ text = "release", limit = 5, allCanvases = true })), " "),
		"node find release --limit 5 --all-canvases --json"
	)
	assert.throwsWith("missing text", function()
		getToolArgv("orion_find", json.object({}))
	end)
end)

test.case("create group takes a label and an optional parent", function(assert)
	assert.eq(
		table.concat(getToolArgv("orion_create_group", json.object({ label = "Week 1" })), " "),
		"group create Week 1 --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_create_group", json.object({ label = "Monday", ["in"] = "week-1" })), " "),
		"group create Monday --in week-1 --json"
	)
end)

test.case("group and ref tools run their subcommands", function(assert)
	assert.eq(
		table.concat(getToolArgv("orion_group", json.object({ label = "Ship", items = { "ci", "pub" } })), " "),
		"group add Ship --items ci,pub --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_remove_group", json.object({ ids = { "ws" }, dryRun = true })), " "),
		"group remove ws --dry-run --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_remove_ref", json.object({ id = "ci", ref = "owner/name#1" })), " "),
		"ref remove ci owner/name#1 --json"
	)
end)

test.case("batch and link tools pass ids, chains, and revision guards through", function(assert)
	assert.eq(
		table.concat(
			getToolArgv("orion_remove", json.object({ ids = { "a", "b" }, reconnect = true, ifRevision = 12 })),
			" "
		),
		"node remove a b --if-revision 12 --reconnect --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_done", json.object({ where = 'label ~ "ship"', dryRun = true })), " "),
		'card done --where label ~ "ship" --dry-run --json'
	)
	assert.eq(
		table.concat(getToolArgv("orion_link", json.object({ from = "a", to = "b", next = { "c" } })), " "),
		"link add a b c --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_insert", json.object({ id = "x", between = "a", targets = { "b" } })), " "),
		"link insert x b --between a --json"
	)
	assert.eq(
		table.concat(
			getToolArgv("orion_update_group", json.object({ id = "g", label = "New", arrange = "custom" })),
			" "
		),
		"group set g --label New --arrange custom --json"
	)
end)

test.case("orion_import passes each ref as a trailing positional", function(assert)
	assert.eq(
		table.concat(
			getToolArgv(
				"orion_import",
				json.object({
					refs = { "https://github.com/vocksel/orion/issues/91", "jira:ABC-1" },
					group = "release",
					dryRun = true,
				})
			),
			" "
		),
		"card import https://github.com/vocksel/orion/issues/91 jira:ABC-1 --group release --dry-run --json"
	)
	assert.throwsWith("refs must be a list of strings", function()
		getToolArgv("orion_import", json.object({ refs = { "" } }))
	end)
end)

test.case("orion_apply passes the plan inline with its dry run and revision", function(assert)
	local steps = json.asArray(json.deserialize([=[[{"op":"addCard","label":"Ship"}]]=]) :: json.Value)
	assert.eq(
		table.concat(
			getToolArgv(
				"orion_apply",
				json.object({ operations = steps, dryRun = true, ifRevision = 4, canvas = "release" })
			),
			" "
		),
		'apply --plan [{"op":"addCard","label":"Ship"}] --dry-run --if-revision 4 --canvas release --json'
	)
	assert.throwsWith("operations must be a list of operations", function()
		getToolArgv("orion_apply", json.object({ operations = {} }))
	end)
end)

test.case("tools reject arguments their schemas do not allow", function(assert)
	assert.throwsWith("unknown argument: colour", function()
		getToolArgv("orion_add_item", json.object({ title = "A", colour = "red" }))
	end)
	assert.throwsWith("status must be one of: todo, active, review, blocked, deferred, done", function()
		getToolArgv("orion_add_item", json.object({ title = "A", status = "later" }))
	end)
	assert.throwsWith("pr must be a positive integer", function()
		getToolArgv("orion_add_item", json.object({ title = "A", pr = 1.5 }))
	end)
	assert.throwsWith("items must be a list of strings", function()
		getToolArgv("orion_group", json.object({ label = "G", items = { 1 } }))
	end)
end)

test.case("mcp tool arguments run the existing command", function(assert)
	local dir = testing.createHarness("mcp-argv")
	local output: { string } = {}
	cli.execute(getToolArgv("orion_add_item", json.object({ title = "From the catalog" })), {
		dataDir = dir,
		write = function(text)
			table.insert(output, text)
		end,
	})
	assert.strContains(table.concat(output, "\n"), "From the catalog")
end)

test.case("update_item passes ref through as --ref and keeps repo and pr as aliases", function(assert)
	assert.eq(
		getToolArgv("orion_update_item", json.object({ id = "pub", ref = "jira:ABC-1" })),
		{ "card", "set", "pub", "--ref", "jira:ABC-1", "--json" }
	)
	assert.eq(
		getToolArgv("orion_add_item", json.object({ title = "Review", repo = "Roblox/avatar", pr = 4 })),
		{ "card", "add", "Review", "--repo", "Roblox/avatar", "--pr", "4", "--json" }
	)
end)

test.case("canvas tools map onto the canvas commands", function(assert)
	assert.eq(
		table.concat(getToolArgv("orion_create_canvas", json.object({ label = "Focus areas" })), " "),
		"canvas create --label Focus areas"
	)
	assert.eq(
		table.concat(getToolArgv("orion_create_canvas", json.object({ name = "focus", label = "Focus" })), " "),
		"canvas create focus --label Focus"
	)
	assert.eq(
		table.concat(getToolArgv("orion_rename_canvas", json.object({ name = "focus", label = "Focus" })), " "),
		"canvas rename focus Focus"
	)
	assert.eq(
		table.concat(getToolArgv("orion_archive_canvas", json.object({ name = "focus" })), " "),
		"canvas archive focus"
	)
	assert.eq(
		table.concat(getToolArgv("orion_restore_canvas", json.object({ name = "focus" })), " "),
		"canvas restore focus"
	)
	assert.eq(
		table.concat(getToolArgv("orion_canvases", json.object({ archived = true })), " "),
		"canvas list --archived --json"
	)
	assert.throwsWith("missing name", function()
		getToolArgv("orion_archive_canvas", json.object({}))
	end)
end)

test.case("log tools attach entries to cards and name the agent that wrote them", function(assert)
	assert.eq(
		table.concat(
			getToolArgv(
				"orion_log_add",
				json.object({ text = "Tested Moments", cards = { "moments", "avatars" }, agent = "claude" })
			),
			" "
		),
		"log add Tested Moments --card moments,avatars --agent claude --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_log_add", json.object({ text = "Canvas-wide", agent = "claude" })), " "),
		"log add Canvas-wide --agent claude --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_log_list", json.object({ card = "moments", limit = 2 })), " "),
		"log list --card moments --limit 2 --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_card_timeline", json.object({ id = "moments", limit = 3 })), " "),
		"card timeline moments --limit 3 --json"
	)
	assert.throwsWith("missing agent", function()
		getToolArgv("orion_log_add", json.object({ text = "No name" }))
	end)
end)

test.case("layout tools map onto group tidy and canvas check", function(assert)
	assert.eq(
		getToolArgv("orion_tidy", json.object({ ids = { "ws", "release" }, dryRun = true, canvas = "focus" })),
		{ "group", "tidy", "ws", "release", "--dry-run", "--canvas", "focus", "--json" }
	)
	assert.eq(
		getToolArgv("orion_tidy", json.object({ where = 'label ~ "release"', ifRevision = 0 })),
		{ "group", "tidy", "--where", 'label ~ "release"', "--if-revision", "0", "--json" }
	)
	assert.eq(getToolArgv("orion_check", json.object({})), { "canvas", "check", "--json" })
	assert.eq(
		getToolArgv("orion_check", json.object({ group = "ws", canvas = "focus" })),
		{ "canvas", "check", "--canvas", "focus", "--group", "ws", "--json" }
	)
	assert.throwsWith("ifRevision must be a nonnegative integer", function()
		getToolArgv("orion_tidy", json.object({ ids = { "ws" }, ifRevision = -1 }))
	end)
	assert.throwsWith("ids must be a list of strings", function()
		getToolArgv("orion_tidy", json.object({ ids = { "" } }))
	end)
	assert.throwsWith("unknown argument: deep", function()
		getToolArgv("orion_tidy", json.object({ ids = { "ws" }, deep = true }))
	end)
end)
