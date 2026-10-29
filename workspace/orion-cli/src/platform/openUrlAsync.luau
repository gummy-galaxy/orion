local getPlatform = require("@root/platform/getPlatform")
local platformTypes = require("@root/platform/types")
local types = require("@root/types")

type CommandRunner = types.CommandRunner
type Platform = platformTypes.Platform

--[[
	Hands a URL to the app registered for its scheme, such as Claude Desktop
	for `claude://`. Windows' `start` would read the `&` in a query as a second
	command, so Windows goes through `url.dll` instead. `platform` defaults to
	the one running Orion.
]]
local function openUrlAsync(url: string, run: CommandRunner, platform: Platform?)
	local current = platform or getPlatform()
	local argv = if current == "macos"
		then { "open", url }
		elseif current == "windows" then { "rundll32", "url.dll,FileProtocolHandler", url }
		else { "xdg-open", url }
	local result = run(argv)

	if not result.ok then
		error(`Could not open {url}: {if result.stderr ~= "" then result.stderr else "nothing handles it"}`, 0)
	end
end

return openUrlAsync
