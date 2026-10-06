local json = require("@std/json")
local net = require("@lute/net/server")

type Socket = net.ServerWebSocket

local events = {}

function events.create()
	local clients: { [Socket]: boolean } = {}
	local hub = {}

	function hub.open(socket: Socket)
		clients[socket] = true
	end

	function hub.close(socket: Socket)
		clients[socket] = nil
	end

	function hub.publish(name: string, data: json.Object)
		local message = json.serialize(json.object({ type = "custom", event = name, data = data }))
		for socket in clients do
			local didSucceed = pcall(function()
				socket:send(message)
			end)
			if not didSucceed then
				clients[socket] = nil
			end
		end
	end

	return hub
end

return table.freeze(events)
