local json = require("@std/json")
local net = require("@lute/net/server")

local shared = require("@root/server/routes/shared")

export type SyncLoop = { getStatus: () -> json.Object, run: (boolean?) -> json.Object }

local sync = {}

function sync.handle(request: net.ReceivedRequest, loop: SyncLoop): shared.Response
	if request.method == "GET" then
		return shared.reply(200, loop.getStatus())
	end
	if request.method == "POST" then
		return shared.reply(200, loop.run(request.query.force == "1"))
	end
	return shared.reply(405, json.object({ error = "method not allowed" }))
end

return table.freeze(sync)
