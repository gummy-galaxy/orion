local json = require("@std/json")
local network = require("@lute/net/server")

local store = require("@root/store")

export type Response = { status: number, body: string, headers: { [string]: string } }

local shared = {}

function shared.reply(status: number, value: json.Value): Response
	return { status = status, body = json.serialize(value), headers = { ["content-type"] = "application/json" } }
end

function shared.parseBody(request: network.ReceivedRequest): json.Object
	return assert(json.asObject(json.deserialize(request.body) :: json.Value), "body must be an object")
end

function shared.getStringField(value: unknown): string?
	return if type(value) == "string" then value else nil
end

function shared.isKnownWorkspace(root: string, name: string): boolean
	if not store.isValidWorkspace(name) then
		return false
	end
	for _, entry in store.getWorkspaces(root).workspaces do
		if entry.name == name then
			return true
		end
	end
	return false
end

return table.freeze(shared)
