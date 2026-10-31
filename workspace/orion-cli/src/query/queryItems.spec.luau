local json = require("@std/json")
local test = require("@std/test")

local queryItems = require("@root/query/queryItems")
local testing = require("@root/testing")
local types = require("@root/types")

local function getIds(items: { types.Item }): string
	local ids: { string } = {}

	for _, item in items do
		table.insert(ids, item.id)
	end

	return table.concat(ids, " ")
end

local function pull(number: number): json.Object
	return json.object({
		refs = { json.object({ source = "github", kind = "pull", key = `gummy-galaxy/orion#{number}` }) },
	})
end

local function createDoc(): types.Doc
	return testing.createDoc({
		testing.group("scope", "Scope"),
		testing.task("nine", "beta", "todo", "scope", pull(9)),
		testing.task("ten", "Alpha", "todo", "scope", pull(10)),
		testing.task("loose", "gamma", "todo"),
		testing.task("shipped", "Delta", "done", "scope", pull(2)),
	})
end

test.case("without where or sort it returns open nodes in canvas order", function(assert)
	local result = queryItems(createDoc(), {})
	assert.eq(getIds(result.items), "scope nine ten loose")
	assert.eq(result.total, 4)
	assert.eq(result.offset, 0)
	assert.eq(result.derived.status.nine, "ready")
end)

test.case("includeDone keeps done cards", function(assert)
	assert.eq(getIds(queryItems(createDoc(), { includeDone = true }).items), "scope nine ten loose shipped")
end)

test.case("filters with the where grammar", function(assert)
	local result = queryItems(createDoc(), { where = [[group = "scope"]], includeDone = true })
	assert.eq(getIds(result.items), "nine ten shipped")
	assert.eq(result.total, 3)

	assert.throwsWith("query at column 1: expected a field or '('", function()
		queryItems(createDoc(), { where = "" })
	end)
end)

test.case("sorts text ignoring case and numbers by size", function(assert)
	local doc = createDoc()
	local byLabel = queryItems(doc, { sort = { { field = "label", isDescending = false } } })
	assert.eq(getIds(byLabel.items), "ten nine loose scope")

	local byPull = queryItems(doc, { sort = { { field = "pr", isDescending = false } }, includeDone = true })
	assert.eq(getIds(byPull.items), "shipped nine ten scope loose")
end)

test.case("missing values sort last in either direction", function(assert)
	local result = queryItems(createDoc(), { sort = { { field = "pr", isDescending = true } } })
	assert.eq(getIds(result.items), "ten nine scope loose")
end)

test.case("ties fall to the next key, then canvas order", function(assert)
	local doc = createDoc()
	local byKind = queryItems(doc, { sort = { { field = "kind", isDescending = true } } })
	assert.eq(getIds(byKind.items), "nine ten loose scope")

	local byKindThenLabel = queryItems(doc, {
		sort = {
			{ field = "kind", isDescending = true },
			{ field = "label", isDescending = false },
		},
	})
	assert.eq(getIds(byKindThenLabel.items), "ten nine loose scope")
end)

test.case("pages after sorting and counts every match", function(assert)
	local doc = createDoc()
	local sort = { { field = "label", isDescending = false } }
	local page = queryItems(doc, { sort = sort, offset = 1, limit = 2 })
	assert.eq(getIds(page.items), "nine loose")
	assert.eq(page.total, 4)
	assert.eq(page.offset, 1)

	assert.eq(getIds(queryItems(doc, { sort = sort, offset = 3, limit = 5 }).items), "scope")
	assert.eq(#queryItems(doc, { offset = 10 }).items, 0)
end)

test.case("refuses offsets and limits that aren't whole numbers", function(assert)
	assert.throwsWith("offset must be a whole number", function()
		queryItems(createDoc(), { offset = -1 })
	end)
	assert.throwsWith("offset must be a whole number", function()
		queryItems(createDoc(), { offset = 1.5 })
	end)
	assert.throwsWith("limit must be a positive integer", function()
		queryItems(createDoc(), { limit = 0 })
	end)
end)

test.case("sorts groups by their path and cards by their group's path", function(assert)
	local doc = testing.createDoc({
		testing.group("zeta", "Zeta"),
		testing.group("alpha", "Alpha"),
		testing.group("inner", "Inner", "zeta"),
		testing.task("in-zeta", "One", "todo", "zeta"),
		testing.task("in-inner", "Two", "todo", "inner"),
		testing.task("in-alpha", "Three", "todo", "alpha"),
	})
	local result = queryItems(doc, { where = [[kind = "step"]], sort = { { field = "group", isDescending = false } } })
	assert.eq(getIds(result.items), "in-alpha in-zeta in-inner")
end)
