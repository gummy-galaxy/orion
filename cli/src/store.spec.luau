local filesystem = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local test = require("@std/test")

local store = require("@root/store")
local testing = require("@root/testing")

test.case("load explains how to create data when none exists", function(assert)
	assert.throwsWith("Open the Orion app once to create it.", function()
		store.load(testing.directory("missing"))
	end)
end)

test.case("store round-trips stack origins without adding one to hand-made links", function(assert)
	local doc = store.decode(
		[[{"nodes":[],"links":[{"id":"a>b","from":"a","to":"b","kind":"blocks","origin":"stack"},{"id":"b>c","from":"b","to":"c","kind":"related"}]}]]
	)
	assert.eq(doc.links[1].origin, "stack")
	assert.eq(doc.links[2].origin, nil)
	local encoded = json.asObject(json.deserialize(store.encode(doc)) :: json.Value)
	local links = if encoded then json.asArray(encoded.links) else nil
	local stack = if links then json.asObject(links[1]) else nil
	local manual = if links then json.asObject(links[2]) else nil
	assert.eq(stack and stack.origin, "stack")
	assert.eq(manual and manual.origin, nil)
end)

test.case("store round-trips top-level GitHub data and unknown fields", function(assert)
	local doc = store.decode(
		[[{"version":1,"revision":0,"settings":{"githubOwner":"flipbook-labs","futureSetting":{"kept":true}},"nodes":[],"links":[],"github":{"viewer":"vocksel","checkedAt":"now","unplaced":[]},"future":{"kept":true}}]]
	)
	doc.settings.sources = { { id = "hop", kind = "hop", command = { "hop" } } }
	local encoded = json.asObject(json.deserialize(store.encode(doc)) :: json.Value)
	local github = if encoded then json.asObject(encoded.github) else nil
	local future = if encoded then json.asObject(encoded.future) else nil
	local settings = if encoded then json.asObject(encoded.settings) else nil
	local futureSetting = if settings then json.asObject(settings.futureSetting) else nil
	local sources = if settings then json.asArray(settings.sources) else nil
	assert.eq(github and github.viewer, "vocksel")
	assert.eq(future and future.kept, true)
	assert.eq(futureSetting and futureSetting.kept, true)
	assert.eq(sources and #sources, 1)
end)

test.case("transaction bumps the revision and keeps fields it doesn't know about", function(assert)
	local directory = testing.directory("roundtrip")
	local doc = testing.createDoc({ testing.task("a", "A", "todo", nil, { future = "kept" }) })
	store.write(directory, doc)
	local after = store.transaction(directory, function(current)
		current.nodes[1].data.status = "done"
	end)

	assert.eq(after.revision, 1)
	local reread = store.load(directory)
	assert.eq(reread.revision, 1)
	assert.eq(reread.nodes[1].data.status, "done")
	assert.eq(reread.nodes[1].data.future, "kept")
	assert.eq(filesystem.exists(path.join(directory, "orion.lock")), false)
end)

test.case("transaction releases the lock when the change fails", function(assert)
	local directory = testing.directory("failure")
	store.write(directory, testing.createDoc({}))
	assert.throws(function()
		store.transaction(directory, function()
			error("nope")
		end)
	end)

	assert.eq(filesystem.exists(path.join(directory, "orion.lock")), false)
	assert.eq(store.load(directory).revision, 0)
end)

test.case("backup names use the replaced revision and UTC second", function(assert)
	assert.eq(store.getBackupName(42, 1791115200), "orion-r42-20261004T120000Z.json")
end)

test.case("transaction saves the exact previous file before replacing it", function(assert)
	local directory = testing.directory("backup")
	store.write(directory, testing.createDoc({ testing.task("a", "Before", "todo") }))
	local before = filesystem.readFileToString(store.filePath(directory))
	store.transaction(directory, function(doc)
		doc.nodes[1].data.label = "After"
	end)

	local backups = store.getBackups(directory)
	assert.eq(#backups, 1)
	assert.eq(backups[1].revision, 0)
	assert.eq(backups[1].size, #before)
	assert.eq(filesystem.readFileToString(backups[1].file), before)
	assert.eq(store.load(directory).nodes[1].data.label, "After")
	store.write(directory, testing.createDoc({}))
	local replaced = store.getBackups(directory)
	assert.eq(#replaced, 2)
	assert.eq(replaced[1].revision, 1)
	assert.eq(store.decode(filesystem.readFileToString(replaced[1].file)).nodes[1].data.label, "After")
end)

test.case("pruning keeps recent backups and one newest backup per UTC day", function(assert)
	local directory = testing.directory("prune")
	local folder = path.join(directory, "backups")
	filesystem.createDirectory(folder, { makeParents = true })
	local names = {
		"orion-r1-20261004T110000Z.json",
		"orion-r2-20261003T130000Z.json",
		"orion-r9-20261003T120000Z.json",
		"orion-r3-20261003T100000Z.json",
		"orion-r4-20261002T230000Z.json",
		"orion-r5-20261002T010000Z.json",
		"orion-r6-20260905T230000Z.json",
		"orion-r7-20260905T010000Z.json",
		"orion-r8-20260904T230000Z.json",
	}

	for _, name in names do
		filesystem.writeStringToFile(path.join(folder, name), name)
	end

	filesystem.writeStringToFile(path.join(folder, "keep-me.json"), "unrelated")
	filesystem.writeStringToFile(path.join(folder, "orion-r9-20261002T010000Z.json.tmp"), "unrelated")
	filesystem.createDirectory(path.join(folder, "orion-r10-20260904T010000Z.json"))
	store.pruneBackups(directory, 1791115200)

	for index, name in names do
		assert.eq(
			filesystem.exists(path.join(folder, name)),
			index == 1 or index == 2 or index == 3 or index == 5 or index == 7
		)
	end

	assert.eq(filesystem.exists(path.join(folder, "keep-me.json")), true)
	assert.eq(filesystem.exists(path.join(folder, "orion-r9-20261002T010000Z.json.tmp")), true)
	assert.eq(filesystem.exists(path.join(folder, "orion-r10-20260904T010000Z.json")), true)
end)
