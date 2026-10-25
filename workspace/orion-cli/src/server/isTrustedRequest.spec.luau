local net = require("@lute/net/server")
local test = require("@std/test")

local isTrustedRequest = require("@root/server/isTrustedRequest")

local PORTS = { 5198, 5199 }

local function createRequest(headers: { [string]: string }): net.ReceivedRequest
	return { method = "POST", path = "/api/merge", body = "{}", query = {}, headers = headers }
end

test.case("isTrustedRequest accepts the server's own address and the dev server", function(assert)
	assert.eq(isTrustedRequest(createRequest({ host = "127.0.0.1:5198" }), "127.0.0.1", PORTS), true)
	assert.eq(
		isTrustedRequest(
			createRequest({ host = "127.0.0.1:5198", origin = "http://127.0.0.1:5198" }),
			"127.0.0.1",
			PORTS
		),
		true
	)
	assert.eq(
		isTrustedRequest(
			createRequest({ host = "localhost:5199", origin = "http://localhost:5199" }),
			"127.0.0.1",
			PORTS
		),
		true
	)
	assert.eq(isTrustedRequest(createRequest({ host = "[::1]:5198" }), "127.0.0.1", PORTS), true)
	assert.eq(isTrustedRequest(createRequest({ host = "192.168.1.4:5198" }), "192.168.1.4", PORTS), true)
end)

test.case("isTrustedRequest refuses a forged Host", function(assert)
	assert.eq(isTrustedRequest(createRequest({ host = "attacker.example:5198" }), "127.0.0.1", PORTS), false)
	assert.eq(isTrustedRequest(createRequest({ host = "127.0.0.1:8080" }), "127.0.0.1", PORTS), false)
	assert.eq(isTrustedRequest(createRequest({ host = "127.0.0.1" }), "127.0.0.1", PORTS), false)
	assert.eq(isTrustedRequest(createRequest({}), "127.0.0.1", PORTS), false)
end)

test.case("isTrustedRequest refuses a foreign Origin", function(assert)
	local function isTrustedFrom(origin: string): boolean
		return isTrustedRequest(createRequest({ host = "127.0.0.1:5198", origin = origin }), "127.0.0.1", PORTS)
	end

	assert.eq(isTrustedFrom("https://attacker.example"), false)
	assert.eq(isTrustedFrom("http://127.0.0.1:8080"), false)
	assert.eq(isTrustedFrom("https://127.0.0.1:5198"), false)
	assert.eq(isTrustedFrom("http://127.0.0.1:5198.attacker.example"), false)
	assert.eq(isTrustedFrom("null"), false)
end)
