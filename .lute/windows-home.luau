--[[
	Points a Windows CI job's home directory at the folder above its checkout.
	Lute bundles packages from ~/.loom/store only into a CLI built from a
	checkout under the home directory, and Windows runners check out to another
	drive. Rokit's tools stay where setup-rokit installed them. Later steps see
	the change through GITHUB_ENV. Does nothing on other platforms.

	lute run windows-home
]]
local fs = require("@std/fs")
local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

local runScript = require("@cli/runScript")

runScript(function()
	if not system.win32 then
		return
	end

	local workspace = assert(process.env.GITHUB_WORKSPACE, "GITHUB_WORKSPACE isn't set")
	local home = tostring(path.dirname(workspace))
	local rokitRoot = tostring(path.join(process.homedir(), ".rokit"))

	local githubEnv = assert(process.env.GITHUB_ENV, "GITHUB_ENV isn't set")
	local existing = if fs.exists(githubEnv) then fs.readFileToString(githubEnv) else ""
	fs.writeStringToFile(githubEnv, `{existing}USERPROFILE={home}\nROKIT_ROOT={rokitRoot}\n`)
	print(`home is now {home}, with Rokit's tools still in {rokitRoot}`)
end)
