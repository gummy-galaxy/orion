local test = require("@std/test")

local resolveInputs = require("@root/import/resolveInputs")
local types = require("@root/types")

type Source = types.Source

local JIRA: Source = {
	id = "jira",
	kind = "jira",
	command = { "acli", "jira" },
	browse = "https://jira.example.com/browse",
}

test.case("inputs resolve with the --ref grammar and failures keep their place", function(assert)
	local entries = resolveInputs({
		"https://jira.example.com/browse/ABC-1",
		"https://git.example.org/Roblox/avatar/pull/1",
		"jira:ABC-2",
	}, { JIRA })

	assert.eq(#entries, 3)
	local first = entries[1].resolved :: types.ResolvedRef
	local third = entries[3].resolved :: types.ResolvedRef
	assert.eq(first.ref.key, "ABC-1")
	assert.eq(entries[1].error, nil)
	assert.strContains(entries[2].error :: string, "no source recognizes https://git.example.org/Roblox/avatar/pull/1")
	assert.eq(entries[2].resolved, nil)
	assert.eq(third.ref.key, "ABC-2")
	assert.eq(third.ref.source, "jira")
end)

test.case("a ref listed twice by key and by URL fails its second listing", function(assert)
	local entries = resolveInputs({ "jira:ABC-1", "https://jira.example.com/browse/ABC-1" }, { JIRA })

	assert.eq(entries[1].resolved ~= nil, true)
	assert.eq(entries[2].error, "listed more than once")
end)

return {}
