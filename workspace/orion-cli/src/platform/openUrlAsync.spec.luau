local test = require("@std/test")

local openUrlAsync = require("@root/platform/openUrlAsync")
local testing = require("@root/testing")
local types = require("@root/types")

type CommandRunner = types.CommandRunner

local URL = "claude://code/new?folder=%2Fwork&q=Go"

local function record(ok: boolean): ({ { string } }, CommandRunner)
	local calls: { { string } } = {}

	return calls, function(argv)
		table.insert(calls, argv)
		return testing.result(ok, "", "no handler")
	end
end

test.case("each platform hands the link to its own opener", function(assert)
	local calls, run = record(true)
	openUrlAsync(URL, run, "macos")
	openUrlAsync(URL, run, "linux")
	openUrlAsync(URL, run, "windows")

	assert.eq(calls[1], { "open", URL })
	assert.eq(calls[2], { "xdg-open", URL })
	assert.eq(calls[3], { "rundll32", "url.dll,FileProtocolHandler", URL })
end)

test.case("a link nothing opens fails with the opener's reason", function(assert)
	local _, run = record(false)
	assert.throws(function()
		openUrlAsync(URL, run, "macos")
	end)
end)
