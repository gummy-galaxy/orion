local path = require("@std/path")

-- Where each package lives. Lute scripts run from the repository root, so these resolve against it.
local CLI_PATH = path.resolve("workspace/orion-cli")

return {
	APP_PATH = path.resolve("workspace/orion-app"),
	CLI_PATH = CLI_PATH,
	DESKTOP_PATH = path.resolve("workspace/orion-desktop"),
	BUILD_PATH = path.join(CLI_PATH, "build"),
	BUILD_OUTPUT = path.join(CLI_PATH, "build", "orion"),
}
