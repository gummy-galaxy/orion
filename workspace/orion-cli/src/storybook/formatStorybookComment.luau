local types = require("@root/storybook/types")

type Story = types.Story

export type Report = {
	storybookUrl: string,
	stories: { Story },
	-- How many imports away each touched stories file is from its nearest changed file, from findTouchedStories.
	touched: { [string]: number },
	-- Whether a stylesheet or Storybook's preview changed, which any story can pick up.
	stylesChanged: boolean,
}

-- Stories this many imports or fewer from a change are listed up front. Further ones reach a change through shared
-- code, such as state, so they're folded away.
local NEAR_DEPTH = 1

type Component = { title: string, stories: { Story } }

local function count(amount: number, singular: string, plural: string): string
	return `{amount} {if amount == 1 then singular else plural}`
end

local function byTitle(a: Story, b: Story): boolean
	local aTitle, bTitle = string.lower(a.title), string.lower(b.title)

	if aTitle ~= bTitle then
		return aTitle < bTitle
	end

	if a.order ~= b.order then
		return a.order < b.order
	end

	return a.name < b.name
end

local function groupByComponent(stories: { Story }): { Component }
	local sorted = table.clone(stories)
	table.sort(sorted, byTitle)

	local components: { Component } = {}

	for _, story in sorted do
		local last = components[#components]

		if last and last.title == story.title then
			table.insert(last.stories, story)
		else
			table.insert(components, { title = story.title, stories = { story } })
		end
	end

	return components
end

-- Lists stories under their sidebar folders, one line per component with a link to each of its stories.
local function formatList(stories: { Story }, baseUrl: string): string
	local lines = {}
	local currentFolder: string? = nil

	for _, component in groupByComponent(stories) do
		local folder, name = string.match(component.title, "^(.*)/([^/]+)$")
		folder = if folder then string.gsub(folder, "/", " › ") else ""
		name = name or component.title

		if folder ~= currentFolder then
			if #lines > 0 then
				table.insert(lines, "")
			end

			if folder ~= "" then
				table.insert(lines, `**{folder}**`)
			end

			currentFolder = folder
		end

		local links = {}

		for _, story in component.stories do
			local label = string.gsub(story.name, "[%[%]]", "\\%0")
			table.insert(links, `[{label}]({baseUrl}/?path=/story/{story.id})`)
		end

		table.insert(lines, `- {name}: {table.concat(links, " · ")}`)
	end

	return table.concat(lines, "\n")
end

local function countComponents(stories: { Story }): number
	return #groupByComponent(stories)
end

--[[
	Writes the Storybook comment for a pull request: a link to its whole Storybook, the stories that load a changed file
	up front, the stories that reach one further down their imports folded away, and every story folded away below
	that, each linked straight to the story.
]]
local function formatStorybookComment(report: Report): string
	local baseUrl = string.gsub(report.storybookUrl, "/+$", "")
	local near, far = {}, {}

	for _, story in report.stories do
		local depth = report.touched[story.file]

		if depth == nil then
			continue
		end

		table.insert(if depth <= NEAR_DEPTH then near else far, story)
	end

	local everything = `{count(#report.stories, "story", "stories")} across {count(
		countComponents(report.stories),
		"component",
		"components"
	)}`
	local sections = {
		"## 📚 Storybook",
		`**[Open this pull request's Storybook ↗]({baseUrl})** · {everything}`,
	}

	if report.stylesChanged then
		table.insert(
			sections,
			"> [!NOTE]\n> This pull request changes stylesheets or Storybook's preview, so any story might look different."
		)
	end

	table.insert(sections, "### 🎯 Stories for what changed")

	if #near > 0 then
		local summary =
			`{count(#near, "story", "stories")} in {count(countComponents(near), "component", "components")}`
		table.insert(sections, `{summary} {if #near == 1 then "loads" else "load"} a changed file directly.`)
		table.insert(sections, formatList(near, baseUrl))
	else
		table.insert(sections, "🌙 No story loads a changed file directly.")
	end

	if #far > 0 then
		local reach = if #far == 1
			then "reaches a change further down its imports"
			else "reach a change further down their imports"
		local summary = `🔭 <b>{count(#far, "more story", "more stories")}</b> {reach}`
		table.insert(sections, `<details>\n<summary>{summary}</summary>\n\n{formatList(far, baseUrl)}\n\n</details>`)
	end

	if #report.stories > 0 then
		table.insert(
			sections,
			`<details>\n<summary>🗂️ <b>Every story</b></summary>\n\n{formatList(report.stories, baseUrl)}\n\n</details>`
		)
	end

	return table.concat(sections, "\n\n") .. "\n"
end

return formatStorybookComment
