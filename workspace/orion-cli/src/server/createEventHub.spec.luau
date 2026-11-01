local json = require("@std/json")
local net = require("@lute/net/server")
local test = require("@std/test")

local createEventHub = require("@root/server/createEventHub")

test.case("event hub sends the custom event payload and drops closed clients", function(expect)
	local eventHub = createEventHub()
	local sent: { string } = {}
	local socket: net.ServerWebSocket = {
		send = function(_self: net.ServerWebSocket, message: string | buffer): number
			if type(message) == "string" then
				table.insert(sent, message)
			end

			return 1
		end,

		close = function(_self: net.ServerWebSocket, _code: number?, _message: string?) end,
	}
	eventHub.open(socket)
	eventHub.publish("orion:changed", json.object({ revision = 4 }))
	local payload = json.asObject(json.deserialize(sent[1]) :: json.Value)
	expect.eq(payload and payload.type, "custom")
	expect.eq(payload and payload.event, "orion:changed")
	local data = if payload then json.asObject(payload.data) else nil
	expect.eq(data and data.revision, 4)
	eventHub.close(socket)
	eventHub.publish("orion:changed", json.object({ revision = 5 }))
	expect.eq(#sent, 1)
end)

test.case("event hub counts the clients that are connected", function(expect)
	local eventHub = createEventHub()
	local socket: net.ServerWebSocket = {
		send = function(_self: net.ServerWebSocket, _message: string | buffer): number
			return 1
		end,

		close = function(_self: net.ServerWebSocket, _code: number?, _message: string?) end,
	}
	expect.eq(eventHub.count(), 0)
	eventHub.open(socket)
	expect.eq(eventHub.count(), 1)
	eventHub.close(socket)
	expect.eq(eventHub.count(), 0)
end)
