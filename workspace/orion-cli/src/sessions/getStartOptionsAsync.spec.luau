local fs = require("@std/fs")
local json = require("@std/json")
local test = require("@std/test")

local getStartOptionsAsync = require("@root/sessions/getStartOptionsAsync")
local testing = require("@root/testing")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type Doc = types.Doc
type Item = types.Item

-- A card on agent/fix whose last session ran in `folder`.
local function card(folder: string?): Item
	local refs: json.Array = {
		json.object({ source = "branch", kind = "branch", key = "owner/repo@agent/fix" }),
	}

	if folder then
		table.insert(
			refs,
			json.object({
				source = "claude",
				kind = "session",
				key = "Fix",
				updatedAt = "2026-10-28T00:00:00Z",
				details = json.object({ cwd = folder }),
			})
		)
	end

	return testing.task("fix", "Fix", "active", nil, { repo = "owner/repo", refs = refs })
end

local function canvas(item: Item, sources: { string }): Doc
	local doc = testing.createDoc({ item })

	for _, kind in sources do
		table.insert(doc.settings.sources, { id = kind, kind = kind })
	end

	return doc
end

-- Answers git with `branch` checked out, and hop with a worktree at
-- `hopFolder`.
local function runner(branch: string, hopFolder: string?): CommandRunner
	return function(argv)
		if argv[1] == "git" then
			return testing.result(true, `{branch}\n`)
		end

		local worktrees: json.Array = {}

		if hopFolder then
			table.insert(
				worktrees,
				json.object({
					path = hopFolder,
					branch = "agent/fix",
					repository = json.object({ remote = "owner/repo" }),
				})
			)
		end

		return testing.result(true, json.serialize(json.object({ worktrees = worktrees })))
	end
end

test.case("a card starts in the folder its last session ran in", function(assert)
	local folder = testing.directory("start-session-folder")
	fs.createDirectory(folder, { makeParents = true })
	local options = getStartOptionsAsync(canvas(card(folder), { "claude" }), card(folder), runner("agent/fix"), {})

	assert.eq(options.agent, "Claude Code")
	assert.eq(options.branch, "agent/fix")
	assert.eq(options.folder, folder)
	assert.eq(options.problem, nil)
	assert.eq(options.presets[1].id, "work")
	fs.removeDirectory(folder, { recursive = true })
end)

test.case("a session folder on another branch gives way to hop's worktree", function(assert)
	local sessionFolder = testing.directory("start-session-moved")
	local hopFolder = testing.directory("start-session-hop")
	fs.createDirectory(sessionFolder, { makeParents = true })
	fs.createDirectory(hopFolder, { makeParents = true })
	local item = card(sessionFolder)
	local options = getStartOptionsAsync(canvas(item, { "claude", "hop" }), item, runner("main", hopFolder), {})

	assert.eq(options.folder, hopFolder)
	fs.removeDirectory(sessionFolder, { recursive = true })
	fs.removeDirectory(hopFolder, { recursive = true })
end)

test.case("a card with no checkout starts in its repository's clone", function(assert)
	local hopFolder = testing.directory("start-session-clone")
	fs.createDirectory(hopFolder, { makeParents = true })
	local item = card()
	local function run(argv: { string })
		local worktree = json.object({
			path = hopFolder,
			branch = "main",
			primary = true,
			repository = json.object({ remote = "owner/repo" }),
		})
		return testing.result(argv[1] == "hop", json.serialize(json.object({ worktrees = { worktree } })))
	end

	local options = getStartOptionsAsync(canvas(item, { "claude", "hop" }), item, run, {})

	assert.eq(options.place, "clone")
	assert.eq(options.folder, hopFolder)
	assert.eq(options.problem, nil)
	fs.removeDirectory(hopFolder, { recursive = true })
end)

test.case("another card's session in the repository finds its clone", function(assert)
	local clone = testing.directory("start-session-common")
	fs.createDirectory(`{clone}/.git`, { makeParents = true })
	local item = card()
	local other = testing.task("other", "Other", "active", nil, {
		repo = "Owner/Repo",
		refs = {
			json.object({ source = "claude", kind = "session", key = "Other", details = json.object({ cwd = clone }) }),
		},
	})
	local doc = canvas(item, { "claude" })
	table.insert(doc.nodes, other)
	local function run(argv: { string })
		local isCommonDir = argv[1] == "git" and argv[4] == "rev-parse"
		return testing.result(isCommonDir, `{clone}/.git\n`)
	end

	local options = getStartOptionsAsync(doc, item, run, {})

	assert.eq(options.place, "clone")
	assert.eq(options.folder, clone)
	fs.removeDirectory(clone, { recursive = true })
end)

test.case("any card can start, with Claude Code when the canvas has no agent", function(assert)
	local item = card()
	local loose = testing.task("loose", "Loose", "todo")
	local options = getStartOptionsAsync(canvas(item, {}), item, runner("main"), {})

	assert.eq(options.agent, "Claude Code")
	assert.eq(options.attaches, false)
	assert.eq(options.place, "none")
	assert.eq(options.folder, nil)
	assert.eq(options.problem, nil)
	assert.eq(getStartOptionsAsync(canvas(loose, {}), loose, runner("main"), {}).problem, nil)

	local group = testing.group("g", "Group")
	assert.strContains(getStartOptionsAsync(canvas(group, {}), group, runner("main"), {}).problem or "", "Only cards")
end)
