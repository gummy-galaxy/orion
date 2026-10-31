local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local test = require("@std/test")

local fileNames = require("@root/fileNames")
local findOtherServer = require("@root/storage/runtime/findOtherServer")
local getVersion = require("@root/common/getVersion")
local testing = require("@root/testing")

local LIVE: findOtherServer.Checks = {
	isAlive = function(_pid: number): boolean
		return true
	end,
	responds = function(_url: string): boolean
		return true
	end,
}

local function writeRecord(root: string, text: string)
	fs.createDirectory(root, { makeParents = true })
	fs.writeStringToFile(path.join(root, fileNames.runtime), text)
end

test.case("a live server from another build is reported with its version", function(assert)
	local root = testing.directory("other-server-version")
	writeRecord(root, [[{"pid":42,"url":"http://127.0.0.1:5198","version":"0.1.0+abc1234"}]])

	local server = findOtherServer(root, LIVE)

	assert.eq(server and server.pid, 42)
	assert.eq(server and server.version, "0.1.0+abc1234")
end)

test.case("a live server that didn't record its build counts as another build", function(assert)
	local root = testing.directory("other-server-legacy")
	writeRecord(root, [[{"pid":42,"url":"http://127.0.0.1:5198","workspace":"default"}]])

	local server = findOtherServer(root, LIVE)

	assert.eq(server and server.pid, 42)
	assert.eq(server and server.version, nil)
end)

test.case("this build, this process, and missing or malformed records don't count", function(assert)
	local root = testing.directory("other-server-none")
	assert.eq(findOtherServer(root, LIVE), nil)

	writeRecord(root, "not json")
	assert.eq(findOtherServer(root, LIVE), nil)

	writeRecord(root, `\{"pid":42,"url":"http://127.0.0.1:5198","version":"{getVersion()}"}`)
	assert.eq(findOtherServer(root, LIVE), nil)

	writeRecord(root, `\{"pid":{process.pid()},"url":"http://127.0.0.1:5198","version":"0.0.1+old"}`)
	assert.eq(findOtherServer(root, LIVE), nil)
end)

test.case("a stale record doesn't count", function(assert)
	local root = testing.directory("other-server-stale")
	writeRecord(root, [[{"pid":42,"url":"http://127.0.0.1:5198","version":"0.0.1+old"}]])

	assert.eq(
		findOtherServer(root, {
			isAlive = function(_pid: number): boolean
				return false
			end,
			responds = function(_url: string): boolean
				error("a dead process shouldn't be asked")
			end,
		}),
		nil
	)
	assert.eq(
		findOtherServer(root, {
			isAlive = function(_pid: number): boolean
				return true
			end,
			responds = function(_url: string): boolean
				return false
			end,
		}),
		nil
	)
end)
