local json = require("@std/json")
local test = require("@std/test")

local testing = require("@root/testing")

local function decode(text: string): json.Object
	return json.asObject(json.deserialize(text) :: json.Value) :: json.Object
end

test.case("a single-item write prints the revision it made with the item", function(assert)
	local _, run = testing.createHarness("write-item-revision")
	local added = decode(run({ "card", "add", "Ship", "--json" }))
	local item = json.asObject(added.item)
	assert.eq(added.revision, 1)
	assert.eq(item and item.label, "Ship")
	assert.eq(item and item.status, "ready")

	local changed = decode(run({ "card", "set", (item :: json.Object).id :: string, "--status", "active", "--json" }))
	assert.eq(changed.revision, 2)
end)

test.case("a note prints a shape without a status", function(assert)
	local _, run = testing.createHarness("write-item-note")
	local note =
		json.asObject(decode(run({ "note", "add", "Waiting", "on", "review", "--after", "ci", "--json" })).item)
	assert.eq(note and note.kind, "note")
	assert.eq(note and note.label, "Waiting on review")
	assert.eq(note and note.status, nil)
	assert.eq(note and note.recordedStatus, nil)
	assert.eq(note and note.unblocks, nil)
	local waitsOn = if note then json.asArray(note.waitsOn) else nil
	assert.eq(waitsOn and waitsOn[1], "ci")
end)

test.case("a group prints what group list does", function(assert)
	local _, run = testing.createHarness("write-item-group")
	local made = json.asObject(decode(run({ "group", "add", "Ship", "--items", "ci,pub", "--json" })).item)
	assert.eq(made and made.kind, "group")
	assert.eq(made and made.status, nil)
	assert.eq(made and made.waitsOn, nil)

	local listed = json.asArray(json.deserialize(run({ "group", "list", "--json" })) :: json.Value)
	local entry: json.Object? = nil

	for _, value in listed or {} do
		local group = json.asObject(value)

		if group and made and group.id == made.id then
			entry = group
		end
	end

	assert.eq(json.serialize(entry :: json.Object), json.serialize(made :: json.Object))
end)
