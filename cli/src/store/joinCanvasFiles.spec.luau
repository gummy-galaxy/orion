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

test.case("joinCanvasFiles puts listed entries first and the rest after them by id", function(assert)
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

test.case("joinCanvasFiles refuses a file that isn't a JSON object", function(assert)
	assert.throws(function()
		joinCanvasFiles({ ["canvas.json"] = "{}", ["nodes/a.json"] = "[]" })
	end)
	assert.throws(function()
		joinCanvasFiles({ ["nodes/a.json"] = [[{"id":"a"}]] })
	end)
end)
