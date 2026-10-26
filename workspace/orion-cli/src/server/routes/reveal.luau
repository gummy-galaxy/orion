local json = require("@std/json")
local net = require("@lute/net/server")

local getStringField = require("@root/getStringField")
local getWorkspaceDir = require("@root/store/getWorkspaceDir")
local loadDoc = require("@root/store/loadDoc")
local shared = require("@root/server/routes/shared")
local useWorkspace = require("@root/store/useWorkspace")

type Response = shared.Response

export type Hub = {
	count: () -> number,
	publish: (name: string, data: json.Object) -> (),
}

local reveal = {}

-- Selects cards or groups in the app and asks it to zoom to them. Switches to
-- their canvas first, the way the app does.
function reveal.handle(
	request: net.ReceivedRequest,
	root: string,
	getActive: () -> string,
	switchTo: (string) -> (),
	hub: Hub?
): Response
	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local didSucceed, response = pcall(function(): Response
		local change = shared.parseBody(request)
		local canvas = getStringField(change.canvas)
		assert(canvas, "canvas must be a string")
		local ids = json.asArray(change.ids)
		assert(ids and #ids > 0, "ids must be a nonempty list of strings")

		for _, id in ids :: json.Array do
			assert(type(id) == "string" and id ~= "", "ids must be a nonempty list of strings")
		end

		if not shared.isKnownWorkspace(root, canvas) then
			return shared.reply(404, json.object({ error = `unknown canvas: {canvas}` }))
		end

		local present: { [string]: boolean } = {}

		for _, node in loadDoc(getWorkspaceDir(root, canvas)).nodes do
			present[node.id] = true
		end

		for _, id in ids :: json.Array do
			if not present[id :: string] then
				return shared.reply(404, json.object({ error = `unknown id: {id}` }))
			end
		end

		-- Checked before switching canvases, so a failed reveal leaves the
		-- canvas where it was.
		if not hub or hub.count() == 0 then
			return shared.reply(409, json.object({ error = "no app is open" }))
		end

		if canvas ~= getActive() then
			useWorkspace(root, canvas)
			switchTo(canvas)
		end

		hub.publish("orion:reveal", json.object({ canvas = canvas, ids = ids, selectOnly = change.selectOnly == true }))
		return shared.reply(200, json.object({ canvas = canvas, ids = ids }))
	end)

	return if didSucceed then response :: Response else shared.reply(400, json.object({ error = tostring(response) }))
end

return table.freeze(reveal)
