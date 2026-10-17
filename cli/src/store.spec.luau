local fs = require("@std/fs")
local json = require("@std/json")
local path = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")

local findRef = require("@root/refs/findRef")
local getRefs = require("@root/refs/getRefs")
local graph = require("@root/graph")
local store = require("@root/store")
local testing = require("@root/testing")

test.case("load reads a missing data file as an empty workspace without writing it", function(assert)
	local dir = testing.directory("missing")
	local doc = store.load(dir)
	assert.eq(doc.revision, 0)
	assert.eq(#doc.nodes, 0)
	assert.eq(#doc.links, 0)
	assert.eq(fs.exists(store.filePath(dir)), false)
end)

test.case("transaction writes the data file on the first change", function(assert)
	local dir = testing.directory("first-change")
	store.transaction(dir, function(doc)
		table.insert(doc.nodes, testing.task("a", "A", "todo"))
	end)

	local reread = store.load(dir)
	assert.eq(reread.revision, 1)
	assert.eq(reread.nodes[1].id, "a")
	assert.eq(#store.getBackups(dir), 0)
	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
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

test.case("store round-trips link labels", function(assert)
	local doc = store.decode(
		[[{"nodes":[],"links":[{"id":"a>b","from":"a","to":"b","kind":"blocks","label":"HTTP"},{"id":"b>c","from":"b","to":"c","kind":"blocks"}]}]]
	)
	assert.eq(doc.links[1].label, "HTTP")
	assert.eq(doc.links[2].label, nil)
	local encoded = json.asObject(json.deserialize(store.encode(doc)) :: json.Value)
	local links = if encoded then json.asArray(encoded.links) else nil
	local labeled = if links then json.asObject(links[1]) else nil
	local plain = if links then json.asObject(links[2]) else nil
	assert.eq(labeled and labeled.label, "HTTP")
	assert.eq(plain and plain.label, nil)
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
	assert.eq(settings and settings.githubOwner, nil)
	assert.eq(encoded and encoded.version, 2)
end)

test.case("decode migrates every legacy card field and remains stable on reread", function(assert)
	local doc = store.decode([[{
		"version":1,"revision":3,
		"settings":{"githubOwner":"Vocksel","future":"kept","sources":[{"id":"hop-local","kind":"hop"}]},
		"nodes":[
			{"id":"pull","type":"task","data":{"repo":"Orion","pr":12,"host":"github.example.com","branch":"feature/A","github":{"state":"OPEN","draft":true,"url":"https://example/pull/12","updatedAt":"yesterday"},"activity":{"lastActiveAt":"today","sessions":["Review"]},"sources":["hop-local"]}},
			{"id":"bare","type":"task","data":{"repo":"Orion","pr":13,"issue":8}},
			{"id":"jira","type":"task","data":{"external":{"source":"jira","key":"ORN-1","url":"https://jira/ORN-1","status":"Done","isDone":true,"updatedAt":"today","details":{"type":"Task"}}}},
			{"id":"branch","type":"task","data":{"repo":"Orion","branch":"feature/B","activity":{"sessions":[]}}},
			{"id":"group","type":"cluster","data":{"repo":"short"}}
		],"links":[],"future":{"kept":true}
	}]])
	assert.eq(doc.version, 2)
	local pull = doc.nodes[1]
	assert.eq(pull.data.repo, "Vocksel/Orion")
	assert.eq((findRef(pull, "pull") :: any).key, "github.example.com/Vocksel/Orion#12")
	assert.eq((findRef(pull, "pull") :: any).url, "https://example/pull/12")
	assert.eq((findRef(pull, "pull") :: any).status, "draft")
	assert.eq((findRef(pull, "branch") :: any).source, "hop-local")
	assert.eq((findRef(pull, "branch") :: any).key, "github.example.com/Vocksel/Orion@feature/A")
	assert.eq(pull.data.pr, nil)
	assert.eq(pull.data.github, nil)
	assert.eq(pull.data.activity, nil)
	assert.eq(pull.data.sources, nil)
	assert.eq((findRef(doc.nodes[2], "pull") :: any).url, "https://github.com/Vocksel/Orion/pull/13")
	assert.eq((findRef(doc.nodes[2], "issue") :: any).key, "Vocksel/Orion#8")
	assert.eq((findRef(doc.nodes[3], "issue") :: any).isDone, true)
	assert.eq((findRef(doc.nodes[4], "branch") :: any).source, "hop")
	assert.eq(doc.nodes[4].data.itemKind, "placeholder")
	assert.eq(doc.nodes[5].data.repo, "short")
	local encoded = store.encode(doc)
	local reread = store.decode(encoded)
	assert.eq(#getRefs(reread.nodes[1]), 2)
	assert.eq(#getRefs(reread.nodes[2]), 2)
	assert.eq(reread.nodes[1].data.repo, "Vocksel/Orion")
	local root = json.asObject(json.deserialize(encoded) :: json.Value)
	local settings = if root then json.asObject(root.settings) else nil
	assert.eq(settings and settings.githubOwner, nil)
	assert.eq(settings and settings.future, "kept")
	assert.eq(root and root.version, 2)
end)

test.case("decode leaves clean version-two cards unchanged and migrates stray legacy fields", function(assert)
	local doc = store.decode(
		[[{"version":2,"settings":{"githubOwner":"Vocksel"},"nodes":[{"id":"clean","type":"task","data":{"repo":"short","refs":[{"source":"jira","kind":"issue","key":"ORN-1"}]}},{"id":"legacy","type":"task","data":{"repo":"orion","pr":3}}],"links":[]}]]
	)
	assert.eq(doc.nodes[1].data.repo, "short")
	assert.eq((findRef(doc.nodes[1], "issue") :: any).key, "ORN-1")
	assert.eq(doc.nodes[2].data.repo, "Vocksel/orion")
	assert.eq((findRef(doc.nodes[2], "pull") :: any).key, "Vocksel/orion#3")
end)

test.case("decode uses the first GitHub source owner for short legacy repos", function(assert)
	local doc = store.decode(
		[[{"version":2,"settings":{"sources":[{"id":"jira","kind":"jira"},{"id":"gh-first","kind":"github","owners":["Roblox","Vocksel"]},{"id":"gh-second","kind":"github","owners":["Other"]}]},"nodes":[{"id":"a","type":"task","data":{"repo":"avatar","pr":12}}],"links":[]}]]
	)
	assert.eq(doc.nodes[1].data.repo, "Roblox/avatar")
	assert.eq((findRef(doc.nodes[1], "pull") :: any).key, "Roblox/avatar#12")

	local default = store.decode(
		[[{"version":1,"settings":{"sources":[{"id":"jira","kind":"jira"}]},"nodes":[{"id":"a","type":"task","data":{"repo":"avatar"}}],"links":[]}]]
	)
	assert.eq(default.nodes[1].data.repo, "flipbook-labs/avatar")
end)

test.case("decode migrates typed sources in a version-one document", function(assert)
	local doc = store.decode([[{
		"version":1,
		"settings":{"sources":[{"id":"gh-vocksel","kind":"github","owners":["Vocksel"]},{"id":"hop-local","kind":"hop"}]},
		"nodes":[
			{"id":"repo","type":"task","data":{"sources":[{"kind":"github-pr","repo":"orion"}]}},
			{"id":"pull","type":"task","data":{"sources":[{"kind":"github-pr","repo":"orion","number":37,"branch":"agent/sticker-wheel","via":"gh-vocksel","state":{"state":"MERGED","draft":false,"url":"https://github.com/Vocksel/orion/pull/37","updatedAt":"now","mergeStateStatus":"UNKNOWN"}}]}},
			{"id":"issue","type":"task","data":{"sources":[{"kind":"github-issue","repo":"flipbook","number":621,"via":"gh-vocksel"}]}},
			{"id":"hop","type":"task","data":{"sources":["hop-local",{"kind":"hop","repo":"changewrite","branch":"release-branch-config","state":{"sessions":[],"lastActiveAt":"2026-10-04T02:32:28Z"}}]}}
		],"links":[]
	}]])
	assert.eq(doc.version, 2)
	assert.eq(doc.nodes[1].data.repo, "Vocksel/orion")
	assert.eq(#getRefs(doc.nodes[1]), 0)
	assert.eq((findRef(doc.nodes[2], "pull") :: any).key, "Vocksel/orion#37")
	assert.eq((findRef(doc.nodes[2], "pull") :: any).isDone, true)
	assert.eq((findRef(doc.nodes[2], "pull") :: any).details.mergeStateStatus, "UNKNOWN")
	assert.eq((findRef(doc.nodes[3], "issue") :: any).key, "Vocksel/flipbook#621")
	assert.eq((findRef(doc.nodes[4], "branch") :: any).source, "hop-local")
	assert.eq((findRef(doc.nodes[4], "branch") :: any).key, "Vocksel/changewrite@release-branch-config")
	for _, item in doc.nodes do
		assert.eq(item.data.sources, nil)
	end
	local reread = store.decode(store.encode(doc))
	assert.eq((findRef(reread.nodes[2], "pull") :: any).key, "Vocksel/orion#37")
end)

test.case("transaction bumps the revision and keeps fields it doesn't know about", function(assert)
	local dir = testing.directory("roundtrip")
	local doc = testing.createDoc({ testing.task("a", "A", "todo", nil, { future = "kept" }) })
	store.write(dir, doc)
	local after = store.transaction(dir, function(current)
		current.nodes[1].data.status = "done"
	end)

	assert.eq(after.revision, 1)
	local reread = store.load(dir)
	assert.eq(reread.revision, 1)
	assert.eq(reread.nodes[1].data.status, "done")
	assert.eq(reread.nodes[1].data.future, "kept")
	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
end)

test.case("transaction releases the lock when the change fails", function(assert)
	local dir = testing.directory("failure")
	store.write(dir, testing.createDoc({}))
	assert.throws(function()
		store.transaction(dir, function()
			error("nope")
		end)
	end)

	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
	assert.eq(store.load(dir).revision, 0)
end)

local function leaveLock(dir: string, owner: string?, isOld: boolean)
	local lockPath = path.join(dir, "orion.lock")
	fs.createDirectory(lockPath, { makeParents = true })

	if owner then
		fs.writeStringToFile(path.join(lockPath, "owner"), owner)
	end

	if isOld then
		assert(process.run({ "touch", "-t", "202001010000", tostring(lockPath) }).ok, "could not age the lock")
	end
end

-- Above any operating system's highest process id, so it never names a live process.
local GONE_PROCESS_ID = 99999999

test.case("transaction reclaims a stale lock whose writer is gone", function(assert)
	local dir = testing.directory("stale-owner")
	store.write(dir, testing.createDoc({}))
	leaveLock(dir, `{GONE_PROCESS_ID} {os.time() - 60}`, false)

	assert.eq(store.transaction(dir, function() end).revision, 1)
	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
end)

test.case("transaction waits out a slow writer that still holds the lock", function(assert)
	local dir = testing.directory("slow-owner")
	store.write(dir, testing.createDoc({}))
	leaveLock(dir, `{process.pid()} {os.time() - 60}`, false)

	assert.throws(function()
		store.transaction(dir, function() end)
	end)

	assert.eq(store.load(dir).revision, 0)
	assert.eq(fs.exists(path.join(dir, "orion.lock")), true)
end)

test.case("transaction reclaims a lock held far past stale, since its process id may be reused", function(assert)
	local dir = testing.directory("ancient-owner")
	store.write(dir, testing.createDoc({}))
	leaveLock(dir, `{process.pid()} {os.time() - 60 * 60}`, false)

	assert.eq(store.transaction(dir, function() end).revision, 1)
end)

test.case("transaction waits on a fresh lock whose writer hasn't stamped it yet", function(assert)
	local dir = testing.directory("fresh-ownerless")
	store.write(dir, testing.createDoc({}))
	leaveLock(dir, nil, false)

	assert.throws(function()
		store.transaction(dir, function() end)
	end)

	assert.eq(store.load(dir).revision, 0)
end)

test.case("transaction reclaims an old lock left without an owner", function(assert)
	local dir = testing.directory("ownerless")
	store.write(dir, testing.createDoc({}))
	leaveLock(dir, nil, true)

	assert.eq(store.transaction(dir, function() end).revision, 1)
	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
end)

test.case("transaction reclaims an old lock with an unreadable owner stamp", function(assert)
	local dir = testing.directory("blank-owner")
	store.write(dir, testing.createDoc({}))
	leaveLock(dir, "", true)

	assert.eq(store.transaction(dir, function() end).revision, 1)
	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
end)

test.case("backup names use the replaced revision and UTC second", function(assert)
	assert.eq(store.getBackupName(42, 1791115200), "orion-r42-20261004T120000Z.json")
end)

test.case("transaction saves the exact previous file before replacing it", function(assert)
	local dir = testing.directory("backup")
	store.write(dir, testing.createDoc({ testing.task("a", "Before", "todo") }))
	local before = fs.readFileToString(store.filePath(dir))
	store.transaction(dir, function(doc)
		doc.nodes[1].data.label = "After"
	end)

	local backups = store.getBackups(dir)
	assert.eq(#backups, 1)
	assert.eq(backups[1].revision, 0)
	assert.eq(backups[1].size, #before)
	assert.eq(fs.readFileToString(backups[1].file), before)
	assert.eq(store.load(dir).nodes[1].data.label, "After")
	store.write(dir, testing.createDoc({}))
	local replaced = store.getBackups(dir)
	assert.eq(#replaced, 2)
	assert.eq(replaced[1].revision, 1)
	assert.eq(store.decode(fs.readFileToString(replaced[1].file)).nodes[1].data.label, "After")
end)

test.case("pruning keeps recent backups and one newest backup per UTC day", function(assert)
	local dir = testing.directory("prune")
	local folder = path.join(dir, "backups")
	fs.createDirectory(folder, { makeParents = true })
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
		fs.writeStringToFile(path.join(folder, name), name)
	end

	fs.writeStringToFile(path.join(folder, "keep-me.json"), "unrelated")
	fs.writeStringToFile(path.join(folder, "orion-r9-20261002T010000Z.json.tmp"), "unrelated")
	fs.createDirectory(path.join(folder, "orion-r10-20260904T010000Z.json"))
	store.pruneBackups(dir, 1791115200)

	for index, name in names do
		assert.eq(
			fs.exists(path.join(folder, name)),
			index == 1 or index == 2 or index == 3 or index == 5 or index == 7
		)
	end

	assert.eq(fs.exists(path.join(folder, "keep-me.json")), true)
	assert.eq(fs.exists(path.join(folder, "orion-r9-20261002T010000Z.json.tmp")), true)
	assert.eq(fs.exists(path.join(folder, "orion-r10-20260904T010000Z.json")), true)
end)

test.case("store keeps the canvas cover and background across later saves", function(assert)
	local dir = testing.directory("canvas-style-store")
	fs.createDirectory(path.join(dir, "assets"), { makeParents = true })
	fs.writeStringToFile(path.join(dir, "assets", "image-logo.png"), "bytes")
	store.transaction(dir, function(doc)
		doc.settings.cover = "image-logo.png"
		doc.settings.background = "#1d1b2e"
	end)
	local reread = store.load(dir)
	assert.eq(reread.settings.cover, "image-logo.png")
	assert.eq(reread.settings.background, "#1d1b2e")
	assert.eq(reread.revision, 1)
	store.transaction(dir, function(doc)
		doc.settings.background = nil
	end)
	local afterLaterSave = store.load(dir)
	assert.eq(afterLaterSave.settings.background, nil)
	assert.eq(afterLaterSave.settings.cover, "image-logo.png")
	assert.eq(afterLaterSave.revision, 2)
	assert.strContains(fs.readFileToString(store.filePath(dir)), '"cover": "image-logo.png"')
end)

test.case("a transaction flags a card that turns done and clears the flag on reopen", function(assert)
	local dir = testing.directory("celebrate-transaction")
	store.write(
		dir,
		testing.createDoc({ testing.task("a", "A", "active"), testing.task("b", "B", "todo") }, { { "a", "b" } })
	)

	store.transaction(dir, function(doc)
		graph.setFields(doc, "a", { status = "done" })
	end)
	local finished = store.load(dir)
	assert.eq(finished.nodes[1].data.celebrate, true)
	assert.eq(finished.nodes[2].data.celebrate, nil)

	store.transaction(dir, function(doc)
		graph.setFields(doc, "a", { status = "todo" })
	end)
	assert.eq(store.load(dir).nodes[1].data.celebrate, nil)
end)

test.case("a save flags the cards it finishes and leaves the rest without the flag", function(assert)
	local dir = testing.directory("celebrate-save")
	store.write(dir, testing.createDoc({ testing.task("a", "A", "active"), testing.task("b", "B", "todo") }))
	local doc = store.load(dir)
	doc.nodes[1].data.status = "done"
	local root = store.toObject(doc)

	local isSaved = store.put(dir, 0, json.asArray(root.nodes) or {}, json.asArray(root.links) or {})
	assert.eq(isSaved, true)
	local saved = store.load(dir)
	assert.eq(saved.nodes[1].data.celebrate, true)
	assert.eq(saved.nodes[2].data.celebrate, nil)
end)

test.case("concurrent CLI writers never lose a change", function(assert)
	local root = testing.directory("concurrent-writers")
	local writers, writesEach = 6, 3
	local environment: { [string]: string } = {}

	for key, value in process.env do
		environment[key] = value
	end

	environment.ORION_DATA_DIR = root
	environment.ORION_CANVAS = nil

	-- Each writer adds its cards one at a time while the others do the same.
	local script = [[
for writer in $(seq 1 "$3"); do
	(for write in $(seq 1 "$4"); do output=$("$1" run "$2" card add "card-$writer-$write" --canvas default 2>&1) || { echo "$output" >&2; exit 1; }; done) &
done
failed=0
for job in $(jobs -p); do wait "$job" || failed=1; done
exit "$failed"
]]
	local result = process.run({
		"sh",
		"-c",
		script,
		"sh",
		tostring(process.execPath()),
		tostring(path.join(process.cwd(), "cli.luau")),
		tostring(writers),
		tostring(writesEach),
	}, { env = environment })
	assert.eq(result.stderr, "")
	assert.eq(result.ok, true)

	local doc = store.load(store.getWorkspaceDir(root, "default"))
	local labels: { [string]: boolean } = {}

	for _, node in doc.nodes do
		labels[tostring(node.data.label)] = true
	end

	assert.eq(doc.revision, writers * writesEach)
	assert.eq(#doc.nodes, writers * writesEach)

	for writer = 1, writers do
		for write = 1, writesEach do
			assert.eq(labels[`card-{writer}-{write}`], true)
		end
	end
end)

test.case("a data file that can't be read refuses writes and stays as it was", function(assert)
	local unreadable: { [string]: string } = { truncated = '{"nodes": [', empty = "", array = "[]", null = "null" }

	for name, contents in unreadable do
		local dir = testing.directory(`unreadable-{name}`)
		fs.createDirectory(dir, { makeParents = true })
		fs.writeStringToFile(store.filePath(dir), contents)

		assert.throws(function()
			store.transaction(dir, function(doc)
				table.insert(doc.nodes, testing.task("a", "A", "todo"))
			end)
		end)

		assert.throws(function()
			store.put(dir, nil, {}, {})
		end)

		assert.eq(fs.readFileToString(store.filePath(dir)), contents)
		assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
		assert.eq(#store.getBackups(dir), 0)
	end
end)

test.case("a save from the app keeps what other writers own", function(assert)
	local dir = testing.directory("save-keeps-others")
	fs.createDirectory(dir, { makeParents = true })
	fs.writeStringToFile(
		store.filePath(dir),
		[[{"version":2,"revision":4,"settings":{"sources":[{"id":"gh","kind":"github","owners":["vocksel"]}]},"github":{"viewer":"vocksel"},"future":{"kept":true},"nodes":[],"links":[]}]]
	)

	local isSaved, revision = store.put(
		dir,
		4,
		{ json.object({ id = "a", type = "task", data = json.object({}) }) },
		{}
	)
	assert.eq(isSaved, true)
	assert.eq(revision, 5)

	local saved = json.asObject(json.deserialize(fs.readFileToString(store.filePath(dir))) :: json.Value) :: json.Object
	local settings = json.asObject(saved.settings) :: json.Object
	local sources = json.asArray(settings.sources) :: json.Array
	assert.eq((json.asObject(sources[1]) :: json.Object).id, "gh")
	assert.eq((json.asObject(saved.github) :: json.Object).viewer, "vocksel")
	assert.eq((json.asObject(saved.future) :: json.Object).kept, true)
	assert.eq(#(json.asArray(saved.nodes) :: json.Array), 1)
end)

test.case("a save from the app based on an older revision changes nothing", function(assert)
	local dir = testing.directory("stale-save")
	store.write(dir, testing.createDoc({ testing.task("a", "A", "todo") }))
	store.transaction(dir, function(doc)
		doc.nodes[1].data.label = "Renamed by the CLI"
	end)

	local before = fs.readFileToString(store.filePath(dir))
	local isSaved, revision = store.put(dir, 0, {}, {})
	assert.eq(isSaved, false)
	assert.eq(revision, 1)
	assert.eq(fs.readFileToString(store.filePath(dir)), before)
end)

test.case("each backup holds the exact revision it replaced", function(assert)
	local dir = testing.directory("backup-chain")
	local written: { [number]: string } = {}
	store.write(dir, testing.createDoc({}))
	written[0] = fs.readFileToString(store.filePath(dir))

	for revision = 1, 4 do
		store.transaction(dir, function(doc)
			table.insert(doc.nodes, testing.task(`card-{revision}`, `Card {revision}`, "todo"))
		end)
		written[revision] = fs.readFileToString(store.filePath(dir))
	end

	local backups = store.getBackups(dir)
	assert.eq(#backups, 4)

	for _, backup in backups do
		assert.eq(fs.readFileToString(backup.file), written[backup.revision])
	end
end)

test.case("a backup that can't be written never blocks the write", function(assert)
	local dir = testing.directory("backup-blocked")
	store.write(dir, testing.createDoc({}))
	fs.writeStringToFile(path.join(dir, "backups"), "not a folder")

	local doc = store.transaction(dir, function(current)
		table.insert(current.nodes, testing.task("a", "A", "todo"))
	end)

	assert.eq(doc.revision, 1)
	assert.eq(store.load(dir).nodes[1].id, "a")
end)

test.case("a save closes out the cards the app finished and closed out at once", function(assert)
	local dir = testing.directory("celebrate-closed-out")
	store.write(
		dir,
		testing.createDoc({
			testing.task("a", "A", "active"),
			testing.task("b", "B", "done", nil, { celebrate = true }),
		})
	)
	local doc = store.load(dir)
	doc.nodes[1].data.status = "done"
	doc.nodes[1].data.celebrate = false
	doc.nodes[2].data.celebrate = false
	local root = store.toObject(doc)

	local isSaved = store.put(dir, 0, json.asArray(root.nodes) or {}, json.asArray(root.links) or {})
	assert.eq(isSaved, true)
	local saved = store.load(dir)
	assert.eq(saved.nodes[1].data.celebrate, nil)
	assert.eq(saved.nodes[2].data.celebrate, nil)
	assert.strNotContains(fs.readFileToString(store.filePath(dir)), "celebrate")
end)
