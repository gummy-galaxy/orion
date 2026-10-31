local json = require("@std/json")
local net = require("@lute/net/server")
local test = require("@std/test")

local telemetry = require("@root/server/routes/telemetry")
local testing = require("@root/testing")

local function createRequest(method: string, body: string?): net.ReceivedRequest
	return {
		method = method,
		path = "/api/telemetry",
		body = body or "",
		query = {} :: { [string]: string },
		headers = {} :: { [string]: string },
	}
end

local function decode(response): json.Object
	return assert(json.asObject(json.deserialize(response.body) :: json.Value))
end

test.case("the app reads an undecided machine and records its answer", function(assert)
	local root = testing.directory("telemetry-route")

	local before = decode(telemetry.handle(createRequest("GET"), root, {}))
	assert.eq(before.choice, "undecided")
	assert.eq(before.enabled, false)

	local response = telemetry.handle(createRequest("POST", '{"enabled":true}'), root, {})
	assert.eq(response.status, 200)
	assert.eq(decode(response).enabled, true)

	local off = decode(telemetry.handle(createRequest("POST", '{"enabled":false}'), root, {}))
	assert.eq(off.choice, "off")
	assert.eq(off.installId, nil)
end)

test.case("the route reports an override from the server's environment", function(assert)
	local root = testing.directory("telemetry-route-override")

	local status = decode(telemetry.handle(createRequest("GET"), root, { ORION_TELEMETRY = "0" }))

	assert.eq(status.override, "ORION_TELEMETRY")
end)

test.case("the route refuses an answer that isn't true or false", function(assert)
	local root = testing.directory("telemetry-route-invalid")

	assert.eq(telemetry.handle(createRequest("POST", '{"enabled":"yes"}'), root, {}).status, 400)
	assert.eq(telemetry.handle(createRequest("PUT", "{}"), root, {}).status, 405)
	assert.eq(decode(telemetry.handle(createRequest("GET"), root, {})).choice, "undecided")
end)
