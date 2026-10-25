local json = require("@std/json")
local net = require("@lute/net/server")
local task = require("@std/task")

local getStringField = require("@root/getStringField")
local mergePull = require("@root/github/mergePull")
local runCommand = require("@root/command")
local shared = require("@root/server/routes/shared")
local sync = require("@root/server/routes/sync")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type SyncLoop = sync.SyncLoop

local PULL_URL = "^https://[%w.-]+/[%w_.-]+/[%w_.-]+/pull/[1-9]%d*/?$"

local merge = {}

function merge.handle(request: net.ReceivedRequest, loop: SyncLoop, runner: CommandRunner?): shared.Response
	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local parsed, body = pcall(shared.parseBody, request)
	local url = if parsed then getStringField(body.url) else nil
	local head = if parsed then getStringField(body.head) else nil

	if not url or not url:match(PULL_URL) or not head or not head:match("^%x+$") then
		return shared.reply(400, json.object({ error = "expected a pull request URL and head commit" }))
	end

	local started, merged, problem = pcall(mergePull, runner or runCommand, url, head)

	if not started then
		return shared.reply(502, json.object({ error = tostring(merged) }))
	elseif not merged then
		return shared.reply(502, json.object({ error = problem }))
	end

	-- Refresh soon after replying so the card turns done without waiting for the next sync.
	task.defer(function()
		pcall(loop.run, true)
	end)

	return shared.reply(200, json.object({}))
end

return table.freeze(merge)
