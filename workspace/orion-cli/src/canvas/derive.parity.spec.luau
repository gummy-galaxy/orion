local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local project = require("@repository/project")

local derive = require("@root/canvas/derive")
local getStringField = require("@root/common/getStringField")
local graphTypes = require("@root/canvas/types")
local migrateItemKind = require("@root/storage/migrations/migrateItemKind")
local testing = require("@root/testing")
local types = require("@root/types")

-- Each case was produced by the app's previous derive over a seeded random
-- canvas, so these checks hold the Luau port to the rules the app used to run.
local FIXTURE = path.join(project.CLI_PATH, "src", "graph", "derive.parity.json")

local function buildDoc(case: json.Object): types.Doc
	local nodes: { types.Item } = {}
	local links: { { string } } = {}

	for _, raw in json.asArray(case.nodes) or {} do
		local node = json.asObject(raw) :: json.Object
		local id = getStringField(node.id) :: string
		local parentId = getStringField(node.parentId)

		if getStringField(node.type) == "cluster" then
			table.insert(nodes, testing.group(id, id, parentId))
		else
			-- The cases record each card's kind from before types, which a read
			-- migrates the same way.
			local item = testing.task(id, id, getStringField(node.status) :: string, parentId)
			item.data.itemKind = getStringField(node.itemKind)
			migrateItemKind(item)
			table.insert(nodes, item)
		end
	end

	for _, raw in json.asArray(case.links) or {} do
		local link = json.asObject(raw) :: json.Object
		table.insert(links, {
			getStringField(link.from) :: string,
			getStringField(link.to) :: string,
			getStringField(link.kind) :: string,
		})
	end

	return testing.createDoc(nodes, links)
end

-- Returns a description of the first difference, or nil when the maps hold the
-- same entries.
local function findMismatch<T>(label: string, expected: json.Object, actual: { [string]: T }): string?
	local count = 0

	for key, value in expected do
		if type(key) ~= "string" then
			continue
		end

		count += 1

		if actual[key] ~= value then
			return `{label}[{key}] expected {tostring(value)}, got {tostring(actual[key])}`
		end
	end

	local actualCount = 0

	for _ in actual do
		actualCount += 1
	end

	if actualCount ~= count then
		return `{label} has {actualCount} entries, expected {count}`
	end

	return nil
end

local function findGroupMismatch(expected: json.Object, actual: { [string]: graphTypes.GroupStats }): string?
	for id, value in expected do
		if type(id) ~= "string" then
			continue
		end

		local stats = json.asObject(value) :: json.Object
		local derivedStats = actual[id]

		if not derivedStats then
			return `groups[{id}] is missing`
		end

		local values = {
			{ "total", stats.total, derivedStats.total },
			{ "done", stats.done, derivedStats.done },
			{ "ready", stats.ready, derivedStats.ready },
			{ "blocked", stats.blocked, derivedStats.blocked },
			{ "outside", stats.outside, derivedStats.outside },
		}

		for _, entry in values do
			if entry[2] ~= entry[3] then
				return `groups[{id}].{entry[1]} expected {tostring(entry[2])}, got {tostring(entry[3])}`
			end
		end
	end

	local expectedCount = 0

	for key in expected do
		if type(key) == "string" then
			expectedCount += 1
		end
	end

	local actualCount = 0

	for _ in actual do
		actualCount += 1
	end

	if actualCount ~= expectedCount then
		return `groups has {actualCount} entries, expected {expectedCount}`
	end

	return nil
end

test.case("derive matches the app's previous rules on seeded canvases", function(assert)
	local root = json.asObject(json.deserialize(fs.readFileToString(FIXTURE)) :: json.Value) :: json.Object
	local cases = json.asArray(root.cases) or {}
	local failure: string? = nil

	for index, raw in cases do
		local case = json.asObject(raw) :: json.Object
		local expected = json.asObject(case.expected) :: json.Object
		local derived = derive(buildDoc(case))
		local mismatch = findMismatch("status", json.asObject(expected.status) :: json.Object, derived.status)
			or findMismatch("flow", json.asObject(expected.flow) :: json.Object, derived.flow)
			or findMismatch("leverage", json.asObject(expected.leverage) :: json.Object, derived.leverage)
			or findMismatch("upstream", json.asObject(expected.upstream) :: json.Object, derived.upstream)
			or findMismatch("rarity", json.asObject(expected.rarity) :: json.Object, derived.rarity)
			or findGroupMismatch(json.asObject(expected.groups) :: json.Object, derived.groups)

		if mismatch and not failure then
			failure = `case {index}: {mismatch}`
		end
	end

	assert.eq(#cases, 150)
	assert.eq(failure, nil)
end)
