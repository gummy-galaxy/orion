local json = require("@std/json")
local net = require("@lute/net/server")

local changeCheckSnooze = require("@root/checks/changeCheckSnooze")
local normalizeUntil = require("@root/checks/normalizeUntil")
local shared = require("@root/server/routes/shared")
local store = require("@root/store")

type Response = shared.Response

local checkSnoozes = {}

-- The app snoozes or unsnoozes a CI job here, for every card in the job's repository. The write is a normal
-- transaction, so it bumps the revision and open windows pick it up.
function checkSnoozes.handle(request: net.ReceivedRequest, root: string, active: string): Response
	if request.method ~= "PUT" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local tagged = request.headers["x-orion-workspace"]
	if tagged and tagged ~= active then
		return shared.reply(409, json.object({ error = "workspace changed" }))
	end

	local didSucceed, failure = pcall(function()
		local change = shared.parseBody(request)
		local repo, name, given = change.repo, change.name, change["until"]
		assert(type(repo) == "string" and type(name) == "string", "repo and name must be strings")
		assert(type(change.snoozed) == "boolean", "snoozed must be true or false")
		assert(given == nil or given == json.null or type(given) == "string", "until must be a time or null")

		local untilTime = if type(given) == "string" then normalizeUntil(given) else nil
		local dir = store.getWorkspaceDir(root, active)
		store.transaction(dir, function(doc)
			changeCheckSnooze(doc, {
				repo = repo,
				name = name,
				snoozed = change.snoozed :: boolean,
				untilTime = untilTime,
				at = os.date("!%Y-%m-%dT%H:%M:%SZ") :: string,
			})
		end)
	end)

	if not didSucceed then
		return shared.reply(400, json.object({ error = tostring(failure) }))
	end

	return shared.reply(200, json.object({}))
end

return table.freeze(checkSnoozes)
