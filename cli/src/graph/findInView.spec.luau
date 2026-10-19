local test = require("@std/test")

local findInView = require("@root/graph/findInView")
local testing = require("@root/testing")

local function fixture()
	return testing.createDoc({
		testing.group("release", "Release"),
		testing.task("ship", "Ship", "todo", "release"),
		testing.group("docs", "Docs", "release"),
		testing.task("write", "Write docs", "todo", "docs"),
		testing.task("api", "Land the API", "review"),
		testing.task("design", "Settle the design", "done"),
		testing.task("far", "Far upstream", "todo"),
		testing.task("after", "After the release", "todo"),
		testing.task("loose", "Loose card", "todo"),
	}, {
		{ "api", "ship" },
		{ "design", "release" },
		{ "far", "api" },
		{ "ship", "after" },
		{ "loose", "write", "relates" },
	})
end

local function sorted(set: { [string]: boolean }): string
	local ids = {}

	for id in set do
		table.insert(ids, id)
	end

	table.sort(ids)
	return table.concat(ids, ",")
end

test.case("nothing is in view without a focus report", function(assert)
	assert.eq(sorted(findInView(fixture(), nil)), "")
end)

test.case("an open group brings its contents at any depth and what blocks them one link away", function(assert)
	local inView = findInView(fixture(), { open = "release", selected = {} })

	assert.eq(sorted(inView), "api,design,docs,release,ship,write")
end)

test.case("a selection with no open group brings the selected cards and their blockers", function(assert)
	local inView = findInView(fixture(), { open = nil, selected = { "api", "after" } })

	assert.eq(sorted(inView), "after,api,far,ship")
end)

test.case("a selected group brings its contents, and ids no longer on the canvas are skipped", function(assert)
	local inView = findInView(fixture(), { open = "gone", selected = { "docs", "missing" } })

	assert.eq(sorted(inView), "docs,write")
end)

test.case("an open id that names a card doesn't count as an open group", function(assert)
	local inView = findInView(fixture(), { open = "loose", selected = {} })

	assert.eq(sorted(inView), "")
end)
