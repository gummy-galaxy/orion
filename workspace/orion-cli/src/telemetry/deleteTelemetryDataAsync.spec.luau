local json = require("@std/json")
local net = require("@std/net")
local test = require("@std/test")

local appendTelemetryQueue = require("@root/telemetry/appendTelemetryQueue")
local deleteTelemetryDataAsync = require("@root/telemetry/deleteTelemetryDataAsync")
local drainTelemetryQueue = require("@root/telemetry/drainTelemetryQueue")
local readTelemetryConsent = require("@root/telemetry/readTelemetryConsent")
local testing = require("@root/testing")
local writeTelemetryConsent = require("@root/telemetry/writeTelemetryConsent")

type Request = { url: string, body: string }

local NOW = "2026-10-30T12:00:00Z"

-- A backend that answers every request with `status` and `body`, or can't be
-- reached when `status` is nil.
local function createBackend(status: number?, body: string?)
	local requests: { Request } = {}

	return requests,
		function(url: string, metadata: net.Metadata, _timeoutSeconds: number): (net.Response?, string?)
			table.insert(requests, { url = url, body = metadata.body or "" })

			if status == nil then
				return nil, "no answer within 15 seconds"
			end

			return { ok = status < 300, status = status, body = body or "", headers = {} }, nil
		end
end

test.case("deleting asks the backend to erase the install and then forgets its id", function(assert)
	local root = testing.directory("telemetry-delete")
	local installId = writeTelemetryConsent(root, true).installId
	appendTelemetryQueue(root, { { name = "cli_command_ran", timestamp = NOW, properties = {} } })
	local requests, backend = createBackend(202, '{"deleted":true}')

	local outcome, failure = deleteTelemetryDataAsync(root, {
		environment = { ORION_TELEMETRY_URL = "http://localhost:3000/telemetry/v1" },
		requestTelemetryAsync = backend,
	})

	assert.eq(outcome, "deleted")
	assert.eq(failure, nil)
	assert.eq(requests[1].url, "http://localhost:3000/telemetry/v1/delete")
	assert.eq((json.deserialize(requests[1].body) :: any).installId, installId)
	assert.eq(readTelemetryConsent(root).choice, "off")
	assert.eq(readTelemetryConsent(root).installId, nil)
	assert.eq(#drainTelemetryQueue(root, NOW), 0)
	assert.neq(writeTelemetryConsent(root, true).installId, installId)
end)

test.case("a machine that never shared has nothing to delete", function(assert)
	local root = testing.directory("telemetry-delete-nothing")
	local requests, backend = createBackend(202)

	assert.eq(deleteTelemetryDataAsync(root, { environment = {}, requestTelemetryAsync = backend }), "nothing")
	assert.eq(#requests, 0)
	assert.eq(readTelemetryConsent(root).choice, "undecided")
end)

test.case("a failed deletion keeps the id and turns sharing off", function(assert)
	local root = testing.directory("telemetry-delete-failed")
	local installId = writeTelemetryConsent(root, true).installId
	local _, unreachable = createBackend(nil)
	local _, refusing = createBackend(429, '{"error":"too many deletions"}')

	local outcome, failure = deleteTelemetryDataAsync(root, { environment = {}, requestTelemetryAsync = unreachable })
	assert.eq(outcome, "failed")
	assert.strContains(failure :: string, "couldn't be reached")
	assert.eq(readTelemetryConsent(root).choice, "off")
	assert.eq(readTelemetryConsent(root).installId, installId)

	outcome, failure = deleteTelemetryDataAsync(root, { environment = {}, requestTelemetryAsync = refusing })
	assert.eq(outcome, "failed")
	assert.strContains(failure :: string, "429: too many deletions")
	assert.eq(readTelemetryConsent(root).installId, installId)
end)
