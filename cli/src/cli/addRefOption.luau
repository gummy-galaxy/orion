local cli = require("@batteries/cli")

local function addRefOption(parser: cli.Parser)
	parser:add("ref", "option", {
		help = "Attach outside work: a GitHub or Jira URL, source:key such as jira:ABC-1, or branch:owner/name@branch",
	})
end

return addRefOption
