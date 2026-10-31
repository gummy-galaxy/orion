local checkOptions = require("@root/sources/checkOptions")
local getOne = require("@root/sources/getOne")
local parseCommand = require("@root/sources/parseCommand")
local types = require("@root/types")

type Source = types.Source

local function createSource(options: { [string]: { string } }): (Source, { string })
	checkOptions("jira", options, { command = true, browse = true })
	local argv = parseCommand(assert(getOne(options, "command"), "jira needs --command"))
	assert(
		argv[1] == "acli" and argv[2] == "jira" and argv[3] == "workitem" and argv[4] == "search",
		"Jira command must be acli jira workitem search"
	)
	local browse = getOne(options, "browse")
	assert(not browse or browse:match("^https://[^/@]+[^@]*$"), "--browse needs an HTTPS URL without credentials")

	local source: Source = {
		id = getOne(options, "id") or "jira",
		kind = "jira",
		browse = if browse then browse:gsub("/+$", "") else nil,
	}

	return source, argv
end

return createSource
