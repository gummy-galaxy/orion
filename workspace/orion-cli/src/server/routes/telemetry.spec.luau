local json = require("@std/json")
local net = require("@lute/net/server")
local test = require("@std/test")

local drainTelemetryQueue = require("@root/telemetry/drainTelemetryQueue")
local getBuild = require("@root/common/getBuild")
local telemetry = require("@root/server/routes/telemetry")
local testing = require("@root/testing")

local NOW = "2026-10-30T12:00:00Z"

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

local function createEventsRequest(body: string): net.ReceivedRequest
	local request = createRequest("POST", body)
	request.path = "/api/telemetry/events"
	return request
end

test.case("the app's events are queued on a machine that opted in", function(assert)
	local root = testing.directory("telemetry-route-events")
	local release = getBuild("e87813e")
	telemetry.handle(createRequest("POST", '{"enabled":true}'), root, {}, release)
	drainTelemetryQueue(root, NOW)

	local response = telemetry.handleEvents(
		createEventsRequest(
			'{"events":[{"name":"app_started","sessionId":"0b7e3a52-5d43-4c8e-8f0e-6d3e1f2a9c11",'
				.. '"properties":{"startup_ms":640}}]}'
		),
		root,
		{},
		release
	)

	assert.eq(response.status, 202)
	assert.eq(decode(response).queued, 1)

	local events = drainTelemetryQueue(root, NOW)
	assert.eq(#events, 1)
	assert.eq(events[1].properties.startup_ms, 640)
end)

test.case("opting in from the app queues telemetry_opted_in from the app", function(assert)
	local root = testing.directory("telemetry-route-opted-in")

	telemetry.handle(createRequest("POST", '{"enabled":true}'), root, {}, getBuild("e87813e"))

	local events = drainTelemetryQueue(root, NOW)
	assert.eq(#events, 1)
	assert.eq(events[1].properties.surface, "app")
end)

test.case("events from a machine that isn't sharing are dropped", function(assert)
	local root = testing.directory("telemetry-route-events-off")

	local response = telemetry.handleEvents(
		createEventsRequest('{"events":[{"name":"app_started"}]}'),
		root,
		{},
		getBuild("e87813e")
	)

	assert.eq(response.status, 202)
	assert.eq(decode(response).queued, 0)
	assert.eq(#drainTelemetryQueue(root, NOW), 0)
end)

test.case("the events route checks only size and shape", function(assert)
	local root = testing.directory("telemetry-route-events-invalid")
	local tooMany = {}

	for _ = 1, 101 do
		table.insert(tooMany, '{"name":"app_started"}')
	end

	assert.eq(telemetry.handleEvents(createEventsRequest('{"events":{}}'), root, {}).status, 400)
	assert.eq(telemetry.handleEvents(createEventsRequest('{"events":[{"name":"App"}]}'), root, {}).status, 400)
	assert.eq(
		telemetry.handleEvents(createEventsRequest(`\{"events":[{table.concat(tooMany, ",")}]\}`), root, {}).status,
		413
	)

	local get = createEventsRequest("")
	get.method = "GET"
	assert.eq(telemetry.handleEvents(get, root, {}).status, 405)
end)
