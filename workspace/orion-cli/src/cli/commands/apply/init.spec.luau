local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local getItem = require("@root/canvas/items/getItem")
local loadDoc = require("@root/storage/canvases/loadDoc")
local testing = require("@root/testing")

-- The first capture of `pattern` in `text`, such as the id a command printed.
local function capture(text: string, pattern: string): string
	return (text:match(pattern) or error(`"{pattern}" isn't in "{text}"`)) :: string
end

test.case("a plan creates cards, notes, and groups, and refers to them by handle", function(assert)
	local dir, run = testing.createHarness("apply-plan")
	local output = run({
		"apply",
		"--plan",
		[=[[
			{"op":"addCard","handle":"spec","label":"Write spec","group":"ws"},
			{"op":"addCard","handle":"build","label":"Build it","group":"ws","status":"active"},
			{"op":"link","from":"@spec","to":"@build"},
			{"op":"link","from":"pub","to":"@spec"},
			{"op":"addNote","text":"Ship it note","after":"@build"},
			{"op":"group","handle":"milestone","label":"Milestone","items":["@spec","@build"]}
		]]=],
	})
	assert.strContains(output, "Applied 6 operations at revision 0 → 1")
	local doc = loadDoc(dir)
	local spec = capture(output, "@spec → (%S+)")
	local milestone = capture(output, "@milestone → (%S+)")
	assert.eq(getItem(doc, spec).data.label, "Write spec")
	assert.eq(getItem(doc, milestone).data.label, "Milestone")
	assert.eq(doc.revision, 1)
	assert.eq(doc.nodes[#doc.nodes].data.label, "Milestone")
	assert.eq(#doc.links, 4)
end)

test.case("a plan attaches refs, sets fields, and groups new cards with existing ones", function(assert)
	local _, run = testing.createHarness("apply-refs")
	local output = run({
		"apply",
		"--plan",
		[=[[
			{"op":"addCard","handle":"pr","label":"Review fix","group":"ws",
				"ref":"https://github.com/flipbook-labs/flipbook/pull/12"},
			{"op":"setFields","id":"@pr","fields":{"status":"review"}},
			{"op":"group","handle":"ready","label":"Ready","items":["@pr","ci"]}
		]]=],
	})
	local shown = run({ "node", "show", capture(output, "@pr → (%S+)") })
	assert.strContains(shown, "review")
	assert.strContains(shown, "flipbook-labs/flipbook#12")
	assert.strContains(run({ "node", "show", capture(output, "@ready → (%S+)") }), "Report release health")
end)

test.case("a dry run previews the plan and writes nothing", function(assert)
	local dir, run = testing.createHarness("apply-dry")
	local output = run({
		"apply",
		"--plan",
		[=[[{"op":"addCard","handle":"extra","label":"Extra","group":"ws"}]]=],
		"--dry-run",
	})
	assert.strContains(output, "Would apply 1 operation at revision 0")
	assert.eq(testing.isRandomId(output:match("@extra → (%S+)")), true)
	local doc = loadDoc(dir)
	assert.eq(doc.revision, 0)
	assert.eq(#doc.nodes, 3)
end)

test.case("a plan that fails partway writes nothing", function(assert)
	local dir, run = testing.createHarness("apply-atomic")
	assert.throwsWith('operation 2 (link): no item or group with id "missing"', function()
		run({
			"apply",
			"--plan",
			[=[[
				{"op":"addCard","label":"Extra","group":"ws"},
				{"op":"link","from":"pub","to":"missing"}
			]]=],
		})
	end)
	local doc = loadDoc(dir)
	assert.eq(doc.revision, 0)
	assert.eq(#doc.nodes, 3)
end)

test.case("a plan with an unknown field, an undeclared handle, or a move without a group is refused", function(assert)
	local _, run = testing.createHarness("apply-refuse")
	assert.throwsWith("lable is not a field of addCard", function()
		run({ "apply", "--plan", [=[[{"op":"addCard","label":"x","lable":"y"}]]=] })
	end)
	assert.throwsWith("unknown handle @nope; declare it in an earlier step", function()
		run({ "apply", "--plan", [=[[{"op":"link","from":"@nope","to":"pub"}]]=] })
	end)
	assert.throwsWith("move needs group, or null for the top level", function()
		run({ "apply", "--plan", [=[[{"op":"move","id":"pub"}]]=] })
	end)
end)

test.case("move with null takes an item to the top level", function(assert)
	local dir, run = testing.createHarness("apply-move")
	run({ "apply", "--plan", [=[[{"op":"move","id":"pub","group":null}]]=] })
	local item = loadDoc(dir).nodes[3]
	assert.eq(item.id, "pub")
	assert.eq(item.parentId, nil)
end)

test.case("a plan can refuse a stale revision and can print JSON with the ids", function(assert)
	local _, run = testing.createHarness("apply-json")
	assert.throwsWith("revision changed: expected 5, current 0", function()
		run({
			"apply",
			"--plan",
			[=[[{"op":"addCard","label":"Extra","group":"ws"}]]=],
			"--if-revision",
			"5",
		})
	end)
	local value = json.asObject(json.deserialize(run({
		"apply",
		"--plan",
		[=[[{"op":"addCard","handle":"extra","label":"Extra","group":"ws"}]]=],
		"--json",
	})) :: json.Value)
	assert.eq(value and value.action, "apply")
	assert.eq(value and value.revision, 1)
	local ids = json.asObject(value and value.ids :: json.Value)
	local id = ids and ids.extra
	assert.eq(testing.isRandomId(id), true)
end)

test.case("a plan file is read from its path, and a missing plan is refused", function(assert)
	local dir, run = testing.createHarness("apply-file")
	local file = tostring(path.join(testing.directory("apply-file-plan"), "plan.json"))
	fs.createDirectory(path.dirname(file), { makeParents = true })
	fs.writeStringToFile(file, [=[[{"op":"addNote","text":"From a file","group":"ws"}]]=])
	assert.strContains(run({ "apply", file }), "Applied 1 operation at revision 0 → 1")
	assert.eq(loadDoc(dir).revision, 1)
	assert.throwsWith("give a plan file, - to read stdin, or --plan <json>", function()
		run({ "apply" })
	end)
end)

test.case("a plan places its new cards once their links are in, so a chain lands in a row", function(assert)
	local dir, run = testing.createHarness("apply-place")
	run({
		"apply",
		"--plan",
		[=[[
			{"op":"addCard","handle":"one","label":"One","group":"ws"},
			{"op":"addCard","handle":"two","label":"Two","group":"ws"},
			{"op":"addCard","handle":"three","label":"Three","after":"@two"},
			{"op":"link","from":"pub","to":"@one"},
			{"op":"link","from":"@one","to":"@two"}
		]]=],
	})
	local doc = loadDoc(dir)
	local positions = {}

	-- New cards get random ids, so they're found by label.
	for _, item in doc.nodes do
		positions[if item.id == "pub" then "pub" else item.data.label] = item.position
	end

	assert.eq(positions.One.y, positions.pub.y)
	assert.eq(positions.Two.y, positions.pub.y)
	assert.eq(positions.Three.y, positions.pub.y)
	assert.eq(positions.One.x > positions.pub.x, true)
	assert.eq(positions.Two.x > positions.One.x, true)
	assert.eq(positions.Three.x > positions.Two.x, true)
	assert.eq(doc.nodes[#doc.nodes].parentId, "ws")
end)

test.case("a plan attaches and takes off refs and labels links in one write", function(assert)
	local dir, run = testing.createHarness("apply-associations")
	local output = run({
		"apply",
		"--plan",
		[=[[
			{"op":"attachRef","id":"pub","ref":"https://github.com/flipbook-labs/flipbook/pull/12"},
			{"op":"detachRef","id":"ci","ref":"flipbook-labs/flipbook#658"},
			{"op":"link","from":"ci","to":"pub","label":"Release notes"}
		]]=],
	})
	assert.strContains(output, "Applied 3 operations at revision 0 → 1")
	assert.strContains(output, '  ~ link ci → pub (blocks) "Release notes"')
	assert.strContains(output, "  + ref flipbook-labs/flipbook#12 on pub")
	assert.strContains(output, "  - ref flipbook-labs/flipbook#658 on ci")
	local doc = loadDoc(dir)
	assert.strContains(run({ "node", "show", "pub" }), "flipbook-labs/flipbook#12")
	assert.eq(getItem(doc, "ci").data.refs, nil)
	assert.eq(doc.links[1].label, "Release notes")

	run({ "apply", "--plan", [=[[{"op":"link","from":"ci","to":"pub","label":""}]]=] })
	assert.eq(loadDoc(dir).links[1].label, nil)
end)

test.case("a dry run lists the items, links, and refs a plan would change", function(assert)
	local dir, run = testing.createHarness("apply-preview")
	local value = json.asObject(json.deserialize(run({
		"apply",
		"--plan",
		[=[[
			{"op":"addCard","handle":"docs","label":"Write docs","group":"ws"},
			{"op":"link","from":"pub","to":"@docs","kind":"related"},
			{"op":"unlink","from":"ci","to":"pub"},
			{"op":"detachRef","id":"ci","ref":"https://github.com/flipbook-labs/flipbook/pull/658"}
		]]=],
		"--dry-run",
		"--json",
	})) :: json.Value)
	local changes = json.asObject(value and value.changes :: json.Value) :: json.Object
	local items = json.asObject(changes.items) :: json.Object
	local links = json.asObject(changes.links) :: json.Object
	local refs = json.asObject(changes.refs) :: json.Object
	local docs = (json.asObject(value and value.ids :: json.Value) :: json.Object).docs
	assert.eq((json.asArray(items.added) :: json.Array)[1], docs)
	assert.eq((json.asArray(items.changed) :: json.Array)[1], "ci")
	local added = json.asObject((json.asArray(links.added) :: json.Array)[1]) :: json.Object
	assert.eq(added.from, "pub")
	assert.eq(added.to, docs)
	assert.eq(added.kind, "related")
	local removed = json.asObject((json.asArray(links.removed) :: json.Array)[1]) :: json.Object
	assert.eq(removed.from, "ci")
	local detached = json.asObject((json.asArray(refs.detached) :: json.Array)[1]) :: json.Object
	assert.eq(detached.id, "ci")
	assert.eq(detached.key, "flipbook-labs/flipbook#658")
	assert.eq(#(json.asArray(refs.attached) :: json.Array), 0)
	assert.eq(loadDoc(dir).revision, 0)
end)

test.case("a ref step refuses a group and a ref the card doesn't have", function(assert)
	local _, run = testing.createHarness("apply-ref-refuse")
	assert.throwsWith("operation 1 (attachRef): groups don't take refs; attach it to an item", function()
		run({
			"apply",
			"--plan",
			[=[[{"op":"attachRef","id":"ws","ref":"https://github.com/flipbook-labs/flipbook/pull/1"}]]=],
		})
	end)
	assert.throwsWith('operation 1 (detachRef): "pub" has no ref flipbook-labs/flipbook#658', function()
		run({ "apply", "--plan", [=[[{"op":"detachRef","id":"pub","ref":"flipbook-labs/flipbook#658"}]]=] })
	end)
	assert.throwsWith("operation 1: ref is required", function()
		run({ "apply", "--plan", [=[[{"op":"attachRef","id":"pub"}]]=] })
	end)
end)
