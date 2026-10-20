local json = require("@std/json")
local test = require("@std/test")

local joinCanvasFiles = require("@root/store/joinCanvasFiles")

local function ids(entries: json.Value): string
	local found = {}

	for _, entry in json.asArray(entries) or {} do
		table.insert(found, (json.asObject(entry) :: json.Object).id :: string)
	end

	return table.concat(found, ",")
end

test.case("joinCanvasFiles reads an older canvas.json's order for entries without keys", function(assert)
	local document = joinCanvasFiles({
		["canvas.json"] = [[{"revision":2,"order":{"nodes":["c","a","c","gone"],"links":[]}}]],
		["nodes/a.json"] = [[{"id":"a"}]],
		["nodes/c.json"] = [[{"id":"c"}]],
		["nodes/e.json"] = [[{"id":"e"}]],
		["nodes/b.json"] = [[{"id":"b"}]],
		["links/x.json"] = [[{"id":"x","from":"a","to":"b"}]],
		["local.json"] = [[{"github":{"viewer":"vocksel"}}]],
	})

	assert.eq(ids(document.nodes), "c,a,b,e")
	assert.eq(ids(document.links), "x")
	assert.eq(document.order, nil)
	assert.eq(document.revision, 2)
	assert.eq((json.asObject(document.github) :: json.Object).viewer, "vocksel")
end)

test.case("joinCanvasFiles orders entries by key, then id, and keeps what each file stored apart", function(assert)
	local document, entries = joinCanvasFiles({
		["canvas.json"] = "{}",
		["nodes/a.json"] = [[{"id":"a","order":"a2","changedAt":{"order":"2026-10-18T00:00:00Z"}}]],
		["nodes/b.json"] = [[{"id":"b","order":"a1"}]],
		["nodes/c.json"] = [[{"id":"c","order":"a1"}]],
		["nodes/d.json"] = [[{"id":"d"}]],
		["nodes/e.json"] = [[{"id":"e","order":"not a key"}]],
	})

	assert.eq(ids(document.nodes), "b,c,a,d,e")
	assert.eq((json.asObject((json.asArray(document.nodes) :: json.Array)[1]) :: json.Object).order, nil)
	assert.eq(entries["nodes/a.json"].order, "a2")
	assert.eq((entries["nodes/a.json"].changedAt :: json.Object).order, "2026-10-18T00:00:00Z")
	assert.eq(entries["nodes/e.json"].order, nil)
end)

test.case("joinCanvasFiles refuses a file that isn't a JSON object", function(assert)
	assert.throws(function()
		joinCanvasFiles({ ["canvas.json"] = "{}", ["nodes/a.json"] = "[]" })
	end)
	assert.throws(function()
		joinCanvasFiles({ ["nodes/a.json"] = [[{"id":"a"}]] })
	end)
end)
