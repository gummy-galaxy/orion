local json = require("@std/json")
local test = require("@std/test")

local joinCanvasFiles = require("@root/store/joinCanvasFiles")
local splitDocObject = require("@root/store/splitDocObject")
local storeTypes = require("@root/store/types")

type CanvasSnapshot = storeTypes.CanvasSnapshot

local function parse(text: string): json.Object
	return json.asObject(json.deserialize(text) :: json.Value) :: json.Object
end

local function snapshot(files: { [string]: string }): CanvasSnapshot
	local document, entries = joinCanvasFiles(files)
	return { files = files, document = document, entries = entries }
end

local function node(id: string, label: string): json.Object
	return json.object({ id = id, type = "task", data = json.object({ label = label, status = "todo" }) })
end

test.case("splitDocObject keeps local fields and entries out of canvas.json", function(assert)
	local files = splitDocObject(
		json.object({
			revision = 3,
			settings = json.object({ cover = "image-a.png" }),
			github = json.object({ viewer = "vocksel" }),
			suggestions = json.object({ groups = {} }),
			nodes = { json.object({ id = "a", type = "task", data = json.object({}) }) },
			links = { json.object({ from = "a", to = "b", kind = "blocks" }) },
		}),
		nil,
		"2026-10-18T00:00:00Z"
	)

	local canvas = parse(files["canvas.json"])
	assert.eq(canvas.revision, nil)
	assert.eq(canvas.github, nil)
	assert.eq(canvas.nodes, nil)
	assert.eq(canvas.order, nil)
	assert.eq(parse(files["local.json"]).revision, 3)
	assert.eq(parse(files["local.json"]).github ~= nil, true)
	assert.eq(parse(files["local.json"]).suggestions ~= nil, true)
	assert.eq(parse(files["nodes/a.json"]).id, "a")
	assert.eq(parse(files["links/a%3eb.json"]).id, "a>b")
end)

test.case("splitDocObject writes no local.json without local fields and skips entries without an id", function(assert)
	local files = splitDocObject(
		json.object({
			nodes = { json.object({ type = "task" }) },
			links = { json.object({ kind = "blocks" }) },
		}),
		nil,
		"2026-10-18T00:00:00Z"
	)
	local count = 0

	for _ in files do
		count += 1
	end

	assert.eq(count, 1)
	assert.eq(files["local.json"], nil)
end)

test.case("splitDocObject keeps each entry's order in its own file", function(assert)
	local time = "2026-10-18T00:00:00Z"
	local first = splitDocObject(json.object({ nodes = { node("a", "A"), node("b", "B") } }), nil, time)
	local a, b = parse(first["nodes/a.json"]), parse(first["nodes/b.json"])
	assert.eq((a.order :: string) < (b.order :: string), true)

	local added = splitDocObject(
		json.object({ nodes = { node("a", "A"), node("c", "C"), node("b", "B") } }),
		snapshot(first),
		"2026-10-18T00:00:01Z"
	)
	assert.eq(added["nodes/a.json"], first["nodes/a.json"])
	assert.eq(added["nodes/b.json"], first["nodes/b.json"])

	local c = parse(added["nodes/c.json"]).order :: string
	assert.eq((a.order :: string) < c and c < (b.order :: string), true)
end)

test.case("splitDocObject stamps only the fields that changed", function(assert)
	local first = splitDocObject(json.object({ nodes = { node("a", "A") } }), nil, "2026-10-18T00:00:00Z")
	local stamps = json.asObject(parse(first["nodes/a.json"]).changedAt) :: json.Object
	assert.eq(stamps["data.label"], "2026-10-18T00:00:00Z")
	assert.eq(stamps["data.status"], "2026-10-18T00:00:00Z")
	assert.eq(stamps.order, "2026-10-18T00:00:00Z")

	local renamed = node("a", "Renamed")
	renamed.data = json.object({ label = "Renamed" })
	local second = splitDocObject(json.object({ nodes = { renamed } }), snapshot(first), "2026-10-18T00:00:09Z")
	local changed = json.asObject(parse(second["nodes/a.json"]).changedAt) :: json.Object
	assert.eq(changed["data.label"], "2026-10-18T00:00:09Z")
	assert.eq(changed["data.status"], "2026-10-18T00:00:09Z")
	assert.eq(changed.type, "2026-10-18T00:00:00Z")
	assert.eq(changed.order, "2026-10-18T00:00:00Z")
end)
