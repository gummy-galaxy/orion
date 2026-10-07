local filesystem = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local store = require("@root/store")
local testing = require("@root/testing")

test.case("focus says when the app isn't reporting", function(assert)
	local _, run = testing.createHarness("focus-closed")
	assert.strContains(run({ "focus" }), "isn't open")
	local shown = json.asObject(json.deserialize(run({ "focus", "--json" })) :: json.Value)
	assert.eq(shown and shown.appOpen, false)
end)

test.case("focus shows the open group and the selection the app reported", function(assert)
	local directory, run = testing.createHarness("focus")
	store.transaction(directory, function(doc)
		table.insert(doc.nodes, testing.group("top", "Roadmap"))
		doc.nodes[1].parentId = "top"
	end)
	filesystem.writeStringToFile(
		path.join(directory, "focus.json"),
		[[{"tab":"t","open":"ws","selected":["pub","gone"],"updatedAt":"2026-10-05T00:00:00Z"}]]
	)
	local text = run({ "focus" })
	assert.strContains(text, "Open: ws  Release  0/2 done, 0 ready, inside Roadmap")
	assert.strContains(text, "pub")
	assert.strNotContains(text, "gone")
	local shown = json.asObject(json.deserialize(run({ "focus", "--json" })) :: json.Value)
	local open = if shown then json.asObject(shown.open) else nil
	local trail = if open then json.asArray(open.path) else nil
	local first = if trail then json.asObject(trail[1]) else nil
	local selected = if shown then json.asArray(shown.selected) else nil
	local item = if selected then json.asObject(selected[1]) else nil
	assert.eq(open and open.id, "ws")
	assert.eq(first and first.id, "top")
	assert.eq(selected and #selected, 1)
	assert.eq(item and item.status, "blocked")
end)

test.case("focus at the top level can select a group", function(assert)
	local directory, run = testing.createHarness("focus-top")
	filesystem.writeStringToFile(path.join(directory, "focus.json"), [[{"tab":"t","open":null,"selected":["ws"]}]])
	local text = run({ "focus" })
	assert.strContains(text, "Open: the top level")
	assert.strContains(text, "Release  0/2 done, 0 ready")
	local shown = json.asObject(json.deserialize(run({ "focus", "--json" })) :: json.Value)
	local selected = if shown then json.asArray(shown.selected) else nil
	local group = if selected then json.asObject(selected[1]) else nil
	assert.eq(shown and shown.open, nil)
	assert.eq(group and group.kind, "group")
end)

test.case("focus reads the requested workspace", function(assert)
	local root, run = testing.createHarness("focus-workspace")
	run({ "workspace", "create", "planning" })
	local planning = store.getWorkspaceDirectory(root, "planning")
	store.putFocus(root, "default-tab", nil, { "ws" })
	store.putFocus(planning, "planning-tab", nil, {})

	local current = json.asObject(json.deserialize(run({ "focus", "--json" })) :: json.Value)
	local selected = if current then json.asArray(current.selected) else nil
	assert.eq(selected and #selected, 1)

	local other = json.asObject(json.deserialize(run({ "focus", "--json", "--workspace", "planning" })) :: json.Value)
	local otherSelected = if other then json.asArray(other.selected) else nil
	assert.eq(other and other.appOpen, true)
	assert.eq(otherSelected and #otherSelected, 0)
end)
