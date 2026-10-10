--[[
	Packs the built CLI into a tarball named for this platform, such as `build/orion-linux-x86_64.tar.gz`. CI uploads the
	tarball rather than the binary because artifact uploads drop the executable bit.
]]
local path = require("@std/path")
local process = require("@std/process")
local project = require("@repo/project")
local system = require("@std/system")

local binaryName = if system.win32 then "orion.exe" else "orion"
local platformName = if system.win32 then "windows" elseif system.macos then "macos" else "linux"
local archivePath = path.join(project.BUILD_PATH, `orion-{platformName}-{system.arch}.tar.gz`)

local packed = process.run({
	"tar",
	"-czf",
	tostring(archivePath),
	"-C",
	tostring(project.BUILD_PATH),
	binaryName,
}, { stdio = "inherit" })
assert(packed.ok, `tar failed ({packed.exitcode})`)

print(`Packed {archivePath}`)
