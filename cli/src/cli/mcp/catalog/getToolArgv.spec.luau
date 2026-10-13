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
	assert.eq(table.concat(getToolArgv("orion_move", json.object({ id = "ci" })), " "), "node move ci --top")
	assert.eq(
		table.concat(getToolArgv("orion_move", json.object({ id = "ci", group = "release" })), " "),
		"node move ci --to release"
	)
	assert.throwsWith("missing id", function()
		getToolArgv("orion_inspect", json.object({ view = "show" }))
	end)
end)

test.case("group and ref tools run their subcommands", function(assert)
	assert.eq(
		table.concat(getToolArgv("orion_group", json.object({ label = "Ship", items = { "ci", "pub" } })), " "),
		"group add Ship --items ci,pub --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_remove_group", json.object({ id = "ws", dryRun = true })), " "),
		"group remove ws --dry-run --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_remove_ref", json.object({ id = "ci", ref = "owner/name#1" })), " "),
		"ref remove ci owner/name#1 --json"
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
		table.concat(getToolArgv("orion_create_workspace", json.object({ label = "Focus areas" })), " "),
		"canvas create --label Focus areas"
	)
	assert.eq(
		table.concat(getToolArgv("orion_create_workspace", json.object({ name = "focus", label = "Focus" })), " "),
		"canvas create focus --label Focus"
	)
	assert.eq(
		table.concat(getToolArgv("orion_rename_workspace", json.object({ name = "focus", label = "Focus" })), " "),
		"canvas rename focus Focus"
	)
	assert.eq(
		table.concat(getToolArgv("orion_archive_workspace", json.object({ name = "focus" })), " "),
		"canvas archive focus"
	)
	assert.eq(
		table.concat(getToolArgv("orion_restore_workspace", json.object({ name = "focus" })), " "),
		"canvas restore focus"
	)
	assert.eq(
		table.concat(getToolArgv("orion_workspaces", json.object({ archived = true })), " "),
		"canvas list --archived --json"
	)
	assert.throwsWith("missing name", function()
		getToolArgv("orion_archive_workspace", json.object({}))
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
		table.concat(getToolArgv("orion_log_list", json.object({ card = "moments" })), " "),
		"log list --card moments --json"
	)
	assert.eq(
		table.concat(getToolArgv("orion_card_show", json.object({ id = "moments", limit = 3 })), " "),
		"card show moments --limit 3 --json"
	)
	assert.throwsWith("missing agent", function()
		getToolArgv("orion_log_add", json.object({ text = "No name" }))
	end)
end)
