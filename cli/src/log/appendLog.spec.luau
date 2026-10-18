local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local appendLog = require("@root/log/appendLog")
local readLog = require("@root/log/readLog")
local store = require("@root/store")
local testing = require("@root/testing")

test.case("appends entries without changing the canvas revision", function(assert)
	local dir = testing.directory("log-append")
	store.write(dir, testing.createDoc({ testing.task("a", "Card", "todo") }))

	appendLog(dir, function(entries, doc)
		assert.eq(#entries, 0)
		assert.eq(doc.nodes[1].id, "a")
		return {
			id = "log-1",
			text = "First",
			time = "2026-10-12T18:00:00Z",
			author = { kind = "person", name = "marin" },
			targets = { { kind = "card", id = "a" } },
		}
	end)
	appendLog(dir, function(entries)
		assert.eq(#entries, 1)
		return {
			id = "log-2",
			text = "Second, with\nthe line break kept",
			time = "2026-10-12T19:00:00Z",
			author = { kind = "agent", name = "claude" },
			targets = {},
		}
	end)

	local entries = readLog(dir)
	assert.eq(#entries, 2)
	assert.eq(entries[1].targets[1].id, "a")
	assert.eq(entries[2].text, "Second, with\nthe line break kept")
	assert.eq(entries[2].author.kind, "agent")
	assert.eq(store.load(dir).revision, 0)
	assert.eq(fs.exists(path.join(dir, "orion.lock")), false)
end)
