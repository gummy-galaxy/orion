local fs = require("@std/fs")
local path = require("@std/path")
local test = require("@std/test")

local fileNames = require("@root/fileNames")
local getRunningRuntime = require("@root/storage/runtime/getRunningRuntime")
local readRuntime = require("@root/storage/runtime/readRuntime")
local testing = require("@root/testing")
local writeRuntime = require("@root/storage/runtime/writeRuntime")

test.case("getRunningRuntime checks process and endpoint before reporting", function(assert)
	local root = testing.directory("runtime-status")
	local runtime: readRuntime.Runtime = {
		pid = 123,
		url = "http://127.0.0.1:5198",
		canvas = "default",
		dataFolder = root,
		startedAt = "2026-10-07T00:00:00Z",
	}
	writeRuntime(root, runtime)
	local checkedEndpoint = false
	local running = getRunningRuntime(root, function(pid)
		assert.eq(pid, 123)
		return true
	end, function(url)
		assert.eq(url, runtime.url)
		checkedEndpoint = true
		return true
	end)
	assert.eq(running and running.canvas, "default")
	assert.eq(checkedEndpoint, true)
	assert.eq(
		getRunningRuntime(root, function()
			return false
		end, function()
			error("endpoint should not be checked")
		end),
		nil
	)
	assert.eq(fs.exists(path.join(root, fileNames.runtime)), false)
	writeRuntime(root, runtime)
	assert.eq(
		getRunningRuntime(root, function()
			return true
		end, function()
			return false
		end),
		nil
	)
	assert.eq(fs.exists(path.join(root, fileNames.runtime)), false)
end)

test.case("getRunningRuntime removes malformed records", function(assert)
	local root = testing.directory("runtime-malformed")
	fs.createDirectory(root)
	local file = path.join(root, fileNames.runtime)
	fs.writeStringToFile(file, "not json")
	assert.eq(
		getRunningRuntime(root, function()
			error("process should not be checked")
		end, function()
			error("endpoint should not be checked")
		end),
		nil
	)
	assert.eq(fs.exists(file), false)
end)
