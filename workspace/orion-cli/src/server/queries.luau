local json = require("@std/json")
local net = require("@lute/net/server")

local getStringField = require("@root/common/getStringField")
local runQuery = require("@root/server/runQuery")
local shared = require("@root/server/routes/shared")

type Socket = net.ServerWebSocket

-- `canvas` is nil for a query that follows the active canvas. `answered` is
-- what the socket last heard for it, minus the revision, so a change that
-- leaves its rows alone sends nothing.
type Subscription = { id: string, canvas: string?, request: json.Object, answered: string? }

local EVENT = "orion:query"

local queries = {}

-- Queries the app keeps open over the event socket. The app sends
-- `{ type = "query", id, ... }` with POST /api/query's fields, plus an
-- optional `canvas`, and hears `orion:query` with the id and the answer right
-- away and again whenever a change alters it. Sending the same id again
-- replaces the query, and `{ type = "unquery", id }` drops it. A query that
-- fails answers `{ id, error }` instead. The server watches only the active
-- canvas, so a query naming another one updates when it becomes active.
function queries.create(root: string)
	local bySocket: { [Socket]: { [string]: Subscription } } = {}
	local hub = {}

	local function answer(socket: Socket, subscription: Subscription, active: string)
		local canvas = subscription.canvas or active
		local data: json.Object

		if shared.isKnownWorkspace(root, canvas) then
			local didSucceed, result = pcall(runQuery, root, canvas, subscription.request)
			data = if didSucceed then result :: json.Object else json.object({ error = tostring(result) })
		else
			data = json.object({ error = `unknown canvas: {canvas}` })
		end

		local revision = data.revision
		data.revision = nil
		local answered = json.serialize(data)

		if answered == subscription.answered then
			return
		end

		subscription.answered = answered
		data.id = subscription.id
		data.revision = revision

		pcall(function()
			socket:send(json.serialize(json.object({ type = "custom", event = EVENT, data = data })))
		end)
	end

	function hub.receive(socket: Socket, message: string | buffer, active: string)
		local text = if type(message) == "string" then message else buffer.tostring(message)
		local didSucceed, value = pcall(json.deserialize, text)
		local request = if didSucceed then json.asObject(value :: json.Value) else nil
		local id = if request then getStringField(request.id) else nil

		if not (request and id) then
			return
		end

		local subscriptions = bySocket[socket] or {}
		bySocket[socket] = subscriptions

		if request.type == "unquery" then
			subscriptions[id] = nil
		elseif request.type == "query" then
			local subscription: Subscription = { id = id, canvas = getStringField(request.canvas), request = request }
			subscriptions[id] = subscription
			answer(socket, subscription, active)
		end
	end

	function hub.close(socket: Socket)
		bySocket[socket] = nil
	end

	-- Answers again every query on the active canvas, after it changed or
	-- became active.
	function hub.refresh(active: string)
		for socket, subscriptions in bySocket do
			for _, subscription in subscriptions do
				if (subscription.canvas or active) == active then
					answer(socket, subscription, active)
				end
			end
		end
	end

	return hub
end

return table.freeze(queries)
