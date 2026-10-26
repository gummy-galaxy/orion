local json = require("@std/json")
local net = require("@lute/net/server")

local getStringField = require("@root/getStringField")
local runCommand = require("@root/command")
local shared = require("@root/server/routes/shared")
local types = require("@root/types")

type CommandRunner = types.CommandRunner

local editor = {}

local function foundAsync(name: string, run: CommandRunner): boolean
	local ok, result = pcall(run, { "which", name }, nil)
	return ok and result.ok
end

local function availableAsync(run: CommandRunner): boolean
	return foundAsync("code", run) and foundAsync("hop", run)
end

local function isPullRequestUrl(value: string): boolean
	local owner, repo, number = value:match("^https://github%.com/([%w_.-]+)/([%w_.-]+)/pull/([1-9]%d*)/?$")
	return owner ~= nil and repo ~= nil and number ~= nil
end

function editor.handleAsync(request: net.ReceivedRequest, runner: CommandRunner?): shared.Response
	local run = runner or runCommand
	if request.method == "GET" then
		return shared.reply(200, json.object({ available = availableAsync(run) }))
	end
	if request.method ~= "POST" then
		return shared.reply(405, json.object({ error = "method not allowed" }))
	end

	local parsed, body = pcall(shared.parseBody, request)
	local url = if parsed then getStringField(body.url) else nil
	if not url or not isPullRequestUrl(url) then
		return shared.reply(400, json.object({ error = "expected a GitHub pull request URL" }))
	end
	if not availableAsync(run) then
		return shared.reply(503, json.object({ error = "VS Code and Hop must be available on PATH" }))
	end

	local started, result = pcall(run, { "hop", "to", url }, nil)
	if not started then
		return shared.reply(502, json.object({ error = tostring(result) }))
	end
	if not result.ok then
		return shared.reply(
			502,
			json.object({
				error = if result.stderr ~= "" then result.stderr else "Hop could not open this pull request",
			})
		)
	end
	return shared.reply(200, json.object({}))
end

return table.freeze(editor)
