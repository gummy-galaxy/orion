local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local fileNames = require("@root/fileNames")
local readRuntime = require("@root/server/readRuntime")
local testing = require("@root/testing")
local writeRuntime = require("@root/server/writeRuntime")

test.case("writeRuntime atomically replaces the server record", function(assert)
	local root = testing.directory("runtime-write")
	local runtime: readRuntime.Runtime = {
		pid = 123,
		url = "http://127.0.0.1:5198",
		canvas = "default",
		dataFolder = root,
		startedAt = "2026-10-07T00:00:00Z",
	}
	writeRuntime(root, runtime)
	local first = readRuntime(root)
	assert.eq(first and first.pid, 123)
	runtime.canvas = "ideas"
	writeRuntime(root, runtime)
	local second = readRuntime(root)
	assert.eq(second and second.canvas, "ideas")
	assert.eq(fs.exists(path.join(root, fileNames.runtime)), true)
end)
