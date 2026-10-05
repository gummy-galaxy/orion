local json = require("@std/json")
local test = require("@std/test")

local cli = require("@root/cli")
local refs = require("@root/refs")
local store = require("@root/store")
local testing = require("@root/testing")

local function kinds(list: { refs.Ref }): string
	local out = {}
	for _, ref in list do
		table.insert(out, ref.kind :: string)
	end
	return table.concat(out, ",")
end

test.case("migrate moves legacy fields into ordered sources with provenance", function(assert)
	local item = testing.task(
		"a",
		"Ship it",
		"review",
		nil,
		json.object({
			repo = "flipbook",
			pr = 12,
			branch = "agent/ship",
			github = json.object({ state = "OPEN", url = "https://github.com/flipbook-labs/flipbook/pull/12" }),
			jira = json.object({ key = "ABC-1", status = "In Progress", statusCategory = "indeterminate" }),
			sources = { "gh-flipbook", "jira" },
		})
	)
	refs.migrate(item, { { id = "gh-flipbook", kind = "github" }, { id = "jira", kind = "jira" } })
	assert.eq(item.data.repo, nil)
	assert.eq(item.data.github, nil)
	assert.eq(item.data.itemKind, "pr")
	local ordered = refs.ordered(item)
	assert.eq(kinds(ordered), "jira,github-pr")
	assert.eq(ordered[1].via, "jira")
	assert.eq(ordered[2].via, "gh-flipbook")
	assert.eq(ordered[2].branch, "agent/ship")
	assert.eq(refs.itemTag(item), "ABC-1")
	local driver = refs.driver(item)
	assert.eq(driver and driver.number, 12)
end)

test.case("tracking sources lead the order and give the card its tag", function(assert)
	local item = testing.task("a", "Ticket", "todo", nil)
	refs.attach(item, refs.parse("github-pr", "lua-apps#1", "Roblox"))
	refs.attach(item, refs.parse("jira", "uiblox-5305", "Roblox"))
	refs.attach(item, refs.parse(nil, "https://example.com/doc", "Roblox"))
	assert.eq(kinds(refs.ordered(item)), "jira,github-pr,url")
	assert.eq(refs.itemTag(item), "UIBLOX-5305")
	assert.eq(item.data.itemKind, "pr")
end)

test.case("legacy placeholders and hop steps become sources of their own", function(assert)
	local placeholder = testing.task("p", "Later", "todo", nil, json.object({ repo = "app" }))
	assert.eq(kinds(refs.list(placeholder)), "github-pr")
	assert.eq(placeholder.data.itemKind, "placeholder")
	local step = testing.task(
		"s",
		"Branch",
		"active",
		nil,
		json.object({ repo = "app", branch = "agent/x", activity = json.object({ lastActiveAt = "t" }) })
	)
	assert.eq(kinds(refs.list(step)), "hop")
	assert.eq(step.data.itemKind, "step")
end)

test.case("parse reads URLs and short forms", function(assert)
	local pr = refs.parse(nil, "https://github.com/Roblox/lua-apps/pull/49723", "Roblox")
	assert.eq(pr.kind, "github-pr")
	assert.eq(pr.repo, "lua-apps")
	assert.eq(pr.number, 49723)
	local other = refs.parse(nil, "https://github.com/vocksel/orion/issues/4", "Roblox")
	assert.eq(other.kind, "github-issue")
	assert.eq(other.repo, "vocksel/orion")
	local release = refs.parse(nil, "https://github.com/Roblox/foundation/releases/tag/Foundation%401.112.0", "Roblox")
	assert.eq(release.kind, "github-release")
	assert.eq(release.tag, "Foundation@1.112.0")
	assert.eq(refs.url(release, "Roblox"), "https://github.com/Roblox/foundation/releases/tag/Foundation%401.112.0")
	local ghe = refs.parse(nil, "https://github.example.com/Roblox/avatar/pull/2", "Roblox")
	assert.eq(ghe.host, "github.example.com")
	local jira = refs.parse(nil, "https://roblox.atlassian.net/browse/UIBLOX-5440", "Roblox")
	assert.eq(jira.kind, "jira")
	assert.eq(jira.key, "UIBLOX-5440")
	assert.eq(refs.parse(nil, "https://roblox.slack.com/archives/C1/p2", "Roblox").kind, "slack")
	assert.eq(refs.parse(nil, "https://github.com/Roblox/uiblox/tree/v0.2.282", "Roblox").kind, "url")
	assert.eq(refs.parse("github-release", "uiblox@v0.2.285", "Roblox").tag, "v0.2.285")
	assert.eq(refs.parse("hop", "lua-apps:agent/font", "Roblox").branch, "agent/font")
	assert.eq(refs.parse("github-pr", "foundation", "Roblox").number, nil)
	assert.eq(refs.parseSpec("github-pr:Roblox/uiblox#2168", "Roblox").repo, "uiblox")
	assert.eq((pcall(refs.parse, "github-issue", "app", "Roblox")), false)
end)

test.case("an opened pull request fills the expected one, and the topmost open one drives", function(assert)
	local item = testing.task("a", "Expected", "todo", nil, json.object({ repo = "app" }))
	refs.attach(item, refs.parse("github-pr", "app#5", "flipbook-labs"))
	assert.eq(#refs.list(item), 1)
	assert.eq(item.data.itemKind, "pr")
	refs.attach(item, refs.parse("github-pr", "app#6", "flipbook-labs"))
	refs.pulls(item)[1].state = json.object({ state = "OPEN" })
	refs.pulls(item)[2].state = json.object({ state = "MERGED" })
	local driver = refs.driver(item)
	assert.eq(driver and driver.number, 5)
	refs.pulls(item)[2].state = json.object({ state = "OPEN" })
	driver = refs.driver(item)
	assert.eq(driver and driver.number, 6)
	refs.detach(item, refs.parse("github-pr", "app#6", "flipbook-labs"))
	assert.eq(#refs.list(item), 1)
end)

test.case("attach, detach, and add --source work through the CLI", function(assert)
	local dir = testing.directory("attach")
	local doc = testing.doc({ testing.task("audit", "closure audit", "todo", nil) })
	doc.settings.githubOwner = "Roblox"
	store.write(dir, doc)
	local output = {}
	local function run(args: { string }): string
		table.clear(output)
		cli.execute(args, {
			dataDir = dir,
			workspace = "",
			write = function(text)
				table.insert(output, text)
			end,
		})
		return table.concat(output, "\n")
	end
	run({ "attach", "audit", "jira", "UIBLOX-5442" })
	run({ "attach", "audit", "https://roblox.slack.com/archives/C1/p2", "--label", "Thread" })
	local shown = json.asObject(json.deserialize(run({ "show", "audit", "--json" })) :: json.Value)
	local sources = if shown then json.asArray(shown.sources) else nil
	assert.eq(sources and #sources, 2)
	local first = if sources then json.asObject(sources[1]) else nil
	assert.eq(first and first.key, "UIBLOX-5442")
	assert.strContains(run({ "show", "audit" }), "source   jira UIBLOX-5442")
	run({ "detach", "audit", "jira", "UIBLOX-5442" })
	assert.eq(#refs.list(store.load(dir).nodes[1]), 1)

	run({ "add", "Foundation 1.112.0", "--source", "github-release:foundation@Foundation@1.112.0" })
	local added = store.load(dir).nodes[2]
	local release = refs.list(added)[1]
	assert.eq(release.kind, "github-release")
	assert.eq(release.tag, "Foundation@1.112.0")
end)
