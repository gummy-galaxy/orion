local fs = require("@std/fs")
local test = require("@std/test")

local appendLog = require("@root/log/appendLog")
local getLogPath = require("@root/log/getLogPath")
local readLog = require("@root/log/readLog")
local testing = require("@root/testing")
local writeDoc = require("@root/store/writeDoc")

test.case("skips an append that never finished and refuses a damaged line", function(assert)
	local dir = testing.directory("log-damaged")
	writeDoc(dir, testing.createDoc({ testing.task("a", "Card", "todo") }))
	appendLog(dir, function()
		return {
			id = "log-1",
			text = "Kept",
			time = "2026-10-12T18:00:00Z",
			author = { kind = "person", name = "marin" },
			targets = {},
		}
	end)
	local file = getLogPath(dir)
	fs.writeStringToFile(file, fs.readFileToString(file) .. '{"id":"log-2","text":"Cut of')
	assert.eq(#readLog(dir), 1)

	fs.writeStringToFile(file, fs.readFileToString(file) .. "\nnot json\n")
	assert.throws(function()
		readLog(dir)
	end)
end)
