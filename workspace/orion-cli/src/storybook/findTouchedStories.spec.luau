local test = require("@std/test")

local findTouchedStories = require("@root/storybook/findTouchedStories")
local types = require("@root/storybook/types")

type Story = types.Story

local FILES = {
	["app/src/components/Ring.stories.tsx"] = "import { Ring } from './Ring'\n",
	["app/src/components/Ring.tsx"] = "import { ringSize } from '../sizes'\nimport './Ring.css'\n",
	["app/src/components/Ring.css"] = ".ring {}\n",
	["app/src/sizes/index.ts"] = "export * from './scale'\n",
	["app/src/sizes/scale.ts"] = "export const scale = 1\n",
	["app/src/components/Badge.stories.tsx"] = "import { Badge } from './Badge'\n",
	["app/src/components/Badge.tsx"] = "const Ring = await import('./Ring')\n",
}

local function story(file: string): Story
	return { id = file, name = "Default", title = "Interface/Thing", file = file, order = 1 }
end

local STORIES = { story("app/src/components/Ring.stories.tsx"), story("app/src/components/Badge.stories.tsx") }

local function readFile(file: string): string?
	return FILES[file]
end

test.case("findTouchedStories counts a changed stories file as no imports away", function(assert)
	local touched = findTouchedStories(STORIES, { "app/src/components/Ring.stories.tsx" }, readFile)

	assert.eq(touched["app/src/components/Ring.stories.tsx"], 0)
	assert.eq(touched["app/src/components/Badge.stories.tsx"], nil)
end)

test.case("findTouchedStories follows imports to the nearest changed file", function(assert)
	local touched = findTouchedStories(STORIES, { "app/src/components/Ring.tsx" }, readFile)

	assert.eq(touched["app/src/components/Ring.stories.tsx"], 1)
	assert.eq(touched["app/src/components/Badge.stories.tsx"], 2)
end)

test.case("findTouchedStories resolves a folder's index file", function(assert)
	local touched = findTouchedStories(STORIES, { "app/src/sizes/scale.ts" }, readFile)

	assert.eq(touched["app/src/components/Ring.stories.tsx"], 3)
	assert.eq(touched["app/src/components/Badge.stories.tsx"], 4)
end)

test.case("findTouchedStories follows stylesheet and dynamic imports", function(assert)
	local touched = findTouchedStories(STORIES, { "app/src/components/Ring.css" }, readFile)

	assert.eq(touched["app/src/components/Ring.stories.tsx"], 2)
	assert.eq(touched["app/src/components/Badge.stories.tsx"], 3)
end)

test.case("findTouchedStories leaves out stories that never reach a change", function(assert)
	local touched = findTouchedStories(STORIES, { "cli/src/command.luau" }, readFile)

	assert.eq(next(touched), nil)
end)
