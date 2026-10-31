local test = require("@std/test")

local formatStorybookComment = require("./formatStorybookComment")
local types = require("./types")

type Story = types.Story

local URL = "https://abc--123.chromatic.com/"

local function story(id: string, name: string, title: string, file: string, order: number): Story
	return { id = id, name = name, title = title, file = file, order = order }
end

local STORIES = {
	story("interface-ring--busy", "Busy", "Interface/Chrome/Ring", "Ring.stories.tsx", 2),
	story("interface-ring--default", "Default", "Interface/Chrome/Ring", "Ring.stories.tsx", 1),
	story("canvas-card--done", "Done", "Canvas/Card", "Card.stories.tsx", 1),
	story("app--default", "Default", "App", "App.stories.tsx", 1),
}

test.case("formatStorybookComment links the whole Storybook and counts its stories", function(assert)
	local comment =
		formatStorybookComment({ storybookUrl = URL, stories = STORIES, touched = {}, stylesChanged = false })

	assert.strContains(comment, "## 📚 Storybook")
	assert.strContains(
		comment,
		"**[Open this pull request's Storybook ↗](https://abc--123.chromatic.com)** · 4 stories across 3 components"
	)
	assert.strContains(comment, "🌙 No story loads a changed file directly.")
	assert.strNotContains(comment, "[!NOTE]")
end)

test.case("formatStorybookComment lists stories near a change under their folders in export order", function(assert)
	local comment = formatStorybookComment({
		storybookUrl = URL,
		stories = STORIES,
		touched = { ["Ring.stories.tsx"] = 1 },
		stylesChanged = false,
	})

	assert.strContains(comment, "2 stories in 1 component load a changed file directly.")
	assert.strContains(
		comment,
		"**Interface › Chrome**\n- Ring: [Default](https://abc--123.chromatic.com/?path=/story/interface-ring--default)"
			.. " · [Busy](https://abc--123.chromatic.com/?path=/story/interface-ring--busy)"
	)
end)

test.case("formatStorybookComment folds away stories that reach a change through deeper imports", function(assert)
	local comment = formatStorybookComment({
		storybookUrl = URL,
		stories = STORIES,
		touched = { ["Card.stories.tsx"] = 0, ["App.stories.tsx"] = 3 },
		stylesChanged = false,
	})

	assert.strContains(comment, "1 story in 1 component loads a changed file directly.")
	assert.strContains(
		comment,
		"<summary>🔭 <b>1 more story</b> reaches a change further down its imports</summary>\n\n"
			.. "- App: [Default](https://abc--123.chromatic.com/?path=/story/app--default)\n\n</details>"
	)
end)

test.case("formatStorybookComment lists every story, sorted by folder", function(assert)
	local comment =
		formatStorybookComment({ storybookUrl = URL, stories = STORIES, touched = {}, stylesChanged = false })
	local every = string.match(comment, "<b>Every story</b></summary>(.*)</details>") or ""

	local app = string.find(every, "- App:", 1, true) or 0
	local canvas = string.find(every, "**Canvas**", 1, true) or 0
	local interface = string.find(every, "**Interface › Chrome**", 1, true) or 0

	assert.that(app > 0 and app < canvas and canvas < interface)
end)

test.case("formatStorybookComment notes stylesheet changes and escapes brackets in names", function(assert)
	local comment = formatStorybookComment({
		storybookUrl = URL,
		stories = { story("ring--wide", "Wide [beta]", "Ring", "Ring.stories.tsx", 1) },
		touched = {},
		stylesChanged = true,
	})

	assert.strContains(comment, "> [!NOTE]\n> This pull request changes stylesheets or Storybook's preview")
	assert.strContains(comment, "[Wide \\[beta\\]](https://abc--123.chromatic.com/?path=/story/ring--wide)")
end)
