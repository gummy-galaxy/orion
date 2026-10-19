local json = require("@std/json")
local test = require("@std/test")

local splitDocObject = require("@root/store/splitDocObject")

local function parse(text: string): json.Object
	return json.asObject(json.deserialize(text) :: json.Value) :: json.Object
end

test.case("splitDocObject keeps local fields and entries out of canvas.json", function(assert)
	local files = splitDocObject(json.object({
		revision = 3,
		settings = json.object({ cover = "image-a.png" }),
		github = json.object({ viewer = "vocksel" }),
		suggestions = json.object({ groups = {} }),
		nodes = { json.object({ id = "a", type = "task", data = json.object({}) }) },
		links = { json.object({ from = "a", to = "b", kind = "blocks" }) },
	}))

	local canvas = parse(files["canvas.json"])
	assert.eq(canvas.revision, 3)
	assert.eq(canvas.github, nil)
	assert.eq(canvas.nodes, nil)
	assert.eq(parse(files["local.json"]).github ~= nil, true)
	assert.eq(parse(files["local.json"]).suggestions ~= nil, true)
	assert.eq(parse(files["nodes/a.json"]).id, "a")
	assert.eq(parse(files["links/a%3eb.json"]).id, "a>b")

	local order = json.asObject(canvas.order) :: json.Object
	assert.eq((json.asArray(order.nodes) :: json.Array)[1], "a")
	assert.eq((json.asArray(order.links) :: json.Array)[1], "a>b")
end)

test.case("splitDocObject writes no local.json without local fields and skips entries without an id", function(assert)
	local files = splitDocObject(json.object({
		nodes = { json.object({ type = "task" }) },
		links = { json.object({ kind = "blocks" }) },
	}))
	local count = 0

	for _ in files do
		count += 1
	end

	assert.eq(count, 1)
	assert.eq(files["local.json"], nil)
end)
