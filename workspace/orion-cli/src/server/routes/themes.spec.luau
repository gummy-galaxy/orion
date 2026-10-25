local fs = require("@std/fs")
local json = require("@std/json")
local net = require("@lute/net/server")
local path = require("@std/path")
local test = require("@std/test")

local testing = require("@root/testing")
local themes = require("@root/server/routes/themes")

local function createRequest(method: string): net.ReceivedRequest
	return {
		method = method,
		path = "/api/themes",
		body = "",
		query = {} :: { [string]: string },
		headers = {},
	}
end

local function decodeResponse(response): json.Object
	return assert(json.asObject(json.deserialize(response.body) :: json.Value))
end

test.case("GET lists theme files with their text", function(assert)
	local root = testing.directory("routes-themes")
	local folder = path.join(root, "themes")
	fs.createDirectory(folder, { makeParents = true })
	fs.writeStringToFile(path.join(folder, "dusk.json"), '{"name":"Dusk"}')

	local response = themes.handle(createRequest("GET"), root)
	assert.eq(response.status, 200)
	assert.eq(response.headers["content-type"], "application/json")

	local entries = json.asArray(decodeResponse(response).themes) :: json.Array
	assert.eq(#entries, 1)
	local entry = json.asObject(entries[1]) :: json.Object
	assert.eq(entry.file, "dusk.json")
	assert.eq(entry.text, '{"name":"Dusk"}')
	assert.eq(entry.error, nil)
end)

test.case("GET returns an empty list without a themes folder", function(assert)
	local root = testing.directory("routes-themes-empty")
	fs.createDirectory(root, { makeParents = true })

	local response = themes.handle(createRequest("GET"), root)
	assert.eq(response.status, 200)
	assert.eq(#(json.asArray(decodeResponse(response).themes) :: json.Array), 0)
end)

test.case("other methods are not allowed", function(assert)
	local root = testing.directory("routes-themes-method")

	assert.eq(themes.handle(createRequest("POST"), root).status, 405)
	assert.eq(themes.handle(createRequest("DELETE"), root).status, 405)
end)
