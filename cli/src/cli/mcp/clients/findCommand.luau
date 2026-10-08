local fs = require("@std/fs")
local path = require("@std/path")

local getCommandExtensions = require("@root/cli/mcp/clients/getCommandExtensions")
local getEnvironmentValue = require("@root/cli/mcp/clients/getEnvironmentValue")
local platformDirs = require("@root/platformDirs")

type Platform = platformDirs.Platform

local function findCommand(name: string, environment: { [string]: string }, platform: Platform): string?
	local separator = if platform == "windows" then "[^;]+" else "[^:]+"

	for directory in string.gmatch(getEnvironmentValue(environment, "PATH") or "", separator) do
		for _, extension in getCommandExtensions(platform, environment) do
			local candidate = path.join(directory, name .. extension)

			if fs.exists(candidate) then
				local kind = fs.type(candidate)

				if kind == "file" or kind == "link" then
					return tostring(candidate)
				end
			end
		end
	end

	return nil
end

return findCommand
