local json = require("@std/json")
local test = require("@std/test")

local mergeEntries = require("@root/storage/files/mergeEntries")

local function entry(fields: { [string]: json.Value }, changedAt: { [string]: string }): json.Object
	local object = json.object({ id = "a" })
	local times = json.object({})

	for key, value in fields do
		object[key] = value
	end

	for key, time in changedAt do
		times[key] = time
	end

	object.changedAt = times
	return object
end

local function getData(merged: json.Object): json.Object
	return json.asObject(merged.data) :: json.Object
end

local function getTimes(merged: json.Object): json.Object
	return json.asObject(merged.changedAt) :: json.Object
end

test.case("mergeEntries keeps the newer value of each field", function(assert)
	local ours = entry({ type = "task", data = json.object({ label = "Ours", status = "todo" }) }, {
		type = "2026-10-18T00:00:00Z",
		["data.label"] = "2026-10-18T00:00:05Z",
		["data.status"] = "2026-10-18T00:00:00Z",
	})
	local theirs = entry({ type = "task", data = json.object({ label = "Theirs", status = "done" }) }, {
		type = "2026-10-18T00:00:00Z",
		["data.label"] = "2026-10-18T00:00:01Z",
		["data.status"] = "2026-10-18T00:00:07Z",
	})

	local merged, reversed = mergeEntries(ours, theirs), mergeEntries(theirs, ours)
	assert.eq(getData(merged).label, "Ours")
	assert.eq(getData(merged).status, "done")
	assert.eq(getTimes(merged)["data.status"], "2026-10-18T00:00:07Z")
	assert.eq(getData(reversed).label, "Ours")
	assert.eq(getData(reversed).status, "done")
end)

test.case("mergeEntries lets a newer removal win over an older edit", function(assert)
	local ours = entry({ data = json.object({ note = "Old note" }) }, { ["data.note"] = "2026-10-18T00:00:01Z" })
	local theirs = entry({ data = json.object({}) }, { ["data.note"] = "2026-10-18T00:00:02Z" })

	local merged = mergeEntries(ours, theirs)
	assert.eq(getData(merged).note, nil)
	assert.eq(getTimes(merged)["data.note"], "2026-10-18T00:00:02Z")
end)

test.case("mergeEntries settles a tie the same way from either side", function(assert)
	local ours = entry({ order = "a1" }, { order = "2026-10-18T00:00:00Z" })
	local theirs = entry({ order = "a2" }, { order = "2026-10-18T00:00:00Z" })

	assert.eq(mergeEntries(ours, theirs).order, "a2")
	assert.eq(mergeEntries(theirs, ours).order, "a2")
end)
