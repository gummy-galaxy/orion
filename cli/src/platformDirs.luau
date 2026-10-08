local path = require("@std/path")
local process = require("@std/process")
local system = require("@std/system")

export type Platform = "macos" | "windows" | "linux"

local function current(): Platform
	if system.win32 then
		return "windows"
	elseif system.macos then
		return "macos"
	end

	return "linux"
end

local function absolute(value: string?): string?
	if value and value ~= "" and path.isAbsolute(value) then
		return value
	end

	return nil
end

local function dataDir(platform: Platform, home: string, env: { [string]: string }): string
	if platform == "macos" then
		return tostring(path.join(home, "Library", "Application Support", "Orion"))
	elseif platform == "windows" then
		local base = absolute(env.APPDATA) or tostring(path.join(home, "AppData", "Roaming"))
		return tostring(path.join(base, "Orion"))
	end

	local base = absolute(env.XDG_DATA_HOME) or tostring(path.join(home, ".local", "share"))
	return tostring(path.join(base, "orion"))
end

local function executableName(platform: Platform, name: string): string
	return if platform == "windows" then `{name}.exe` else name
end

return table.freeze({
	current = current,
	dataDir = dataDir,
	executableName = executableName,
	defaultDataDir = function(): string
		return dataDir(current(), tostring(process.homedir()), process.env)
	end,
})
