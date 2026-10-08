local json = require("@std/json")
local net = require("@lute/net/server")
local test = require("@std/test")

local events = require("@root/server/events")

test.case("event hub sends the custom event payload and drops closed clients", function(expect)
	local hub = events.create()
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
	hub.open(socket)
	hub.publish("orion:changed", json.object({ revision = 4 }))
	local payload = json.asObject(json.deserialize(sent[1]) :: json.Value)
	expect.eq(payload and payload.type, "custom")
	expect.eq(payload and payload.event, "orion:changed")
	local data = if payload then json.asObject(payload.data) else nil
	expect.eq(data and data.revision, 4)
	hub.close(socket)
	hub.publish("orion:changed", json.object({ revision = 5 }))
	expect.eq(#sent, 1)
end)
