local json = require("@std/json")
local test = require("@std/test")

local resolveCanvasFiles = require("@root/store/resolveCanvasFiles")

local function getObject(files: { [string]: string }, file: string): json.Object
	return json.asObject(json.deserialize(files[file]) :: json.Value) :: json.Object
end

test.case("resolveCanvasFiles leaves files that parse alone", function(assert)
	local files = { ["canvas.json"] = '{"revision":1}', ["nodes/a.json"] = '{"id":"a"}' }
	local resolved, problems = resolveCanvasFiles(files)

	assert.eq(resolved, files)
	assert.eq(#problems, 0)
end)

test.case("resolveCanvasFiles keeps our side of a conflict and drops a diff3 base", function(assert)
	local resolved, problems = resolveCanvasFiles({
		["canvas.json"] = table.concat({
			"{",
			"<<<<<<< HEAD",
			'  "revision": 4',
			"||||||| base",
			'  "revision": 2',
			"=======",
			'  "revision": 3',
			">>>>>>> theirs",
			"}",
		}, "\n"),
	})

	assert.eq(getObject(resolved, "canvas.json").revision, 4)
	assert.eq(problems[1], "canvas.json has a git conflict; kept HEAD's side")
end)

test.case("resolveCanvasFiles keeps their side when ours doesn't parse", function(assert)
	local resolved, problems = resolveCanvasFiles({
		["links/x.json"] = '<<<<<<< HEAD\n{"id": \n=======\n{"id": "x"}\n>>>>>>> main',
	})

	assert.eq(getObject(resolved, "links/x.json").id, "x")
	assert.eq(problems[1], "links/x.json has a git conflict; kept main's side")
end)

test.case("resolveCanvasFiles leaves out a link nothing can be read from, and fails on canvas.json", function(assert)
	local resolved, problems = resolveCanvasFiles({ ["links/x.json"] = "nope" })
	assert.eq(resolved["links/x.json"], nil)
	assert.eq(problems[1], "links/x.json isn't a JSON object")

	assert.throws(function()
		resolveCanvasFiles({ ["canvas.json"] = "nope" })
	end)
end)

test.case("resolveCanvasFiles names an unreadable node after its escaped file name", function(assert)
	local resolved = resolveCanvasFiles({ ["nodes/%41b.json"] = "nope" })
	assert.eq(getObject(resolved, "nodes/%41b.json").id, "Ab")
end)
