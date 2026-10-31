local json = require("@std/json")
local test = require("@std/test")

local parseStoryIndex = require("./parseStoryIndex")

local STORIES_FILE = "app/src/components/Ring.stories.tsx"

local function entry(id: string, name: string, exportName: string): json.Object
	return json.object({
		type = "story",
		id = id,
		name = name,
		title = "Interface/Ring",
		importPath = "./src/components/Ring.stories.tsx",
		exportName = exportName,
	})
end

local function readFile(file: string): string?
	return if file == STORIES_FILE
		then "export const Default: Story = {}\nexport const Busy: Story = {}\nexport const Empty: Story = {}\n"
		else nil
end

test.case("parseStoryIndex reads stories with their files from the repository root", function(assert)
	local index = json.serialize(json.object({
		v = 5,
		entries = json.object({ ["interface-ring--default"] = entry("interface-ring--default", "Default", "Default") }),
	}))

	local stories = parseStoryIndex(index, "app", readFile)

	assert.eq(#stories, 1)
	assert.eq(stories[1].id, "interface-ring--default")
	assert.eq(stories[1].name, "Default")
	assert.eq(stories[1].title, "Interface/Ring")
	assert.eq(stories[1].file, STORIES_FILE)
	assert.eq(stories[1].order, 1)
end)

test.case("parseStoryIndex orders stories by their export in the stories file", function(assert)
	local index = json.serialize(json.object({
		entries = json.object({
			a = entry("interface-ring--empty", "Empty", "Empty"),
			b = entry("interface-ring--busy", "Busy", "Busy"),
			c = entry("interface-ring--missing", "Missing", "Missing"),
		}),
	}))

	local orders = {}

	for _, story in parseStoryIndex(index, "app", readFile) do
		orders[story.name] = story.order
	end

	assert.eq(orders.Busy, 2)
	assert.eq(orders.Empty, 3)
	assert.eq(orders.Missing, math.huge)
end)

test.case("parseStoryIndex skips docs pages and malformed entries", function(assert)
	local index = json.serialize(json.object({
		entries = json.object({
			docs = json.object({ type = "docs", id = "interface-ring--docs", name = "Docs", title = "Interface/Ring" }),
			broken = json.object({ type = "story", id = "interface-ring--broken" }),
		}),
	}))

	assert.eq(#parseStoryIndex(index, "app", readFile), 0)
end)
