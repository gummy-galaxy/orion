local test = require("@std/test")

local getAdapter = require("@root/adapters/getAdapter")
local refForms = require("@root/adapters/refForms")
local resolveRef = require("@root/adapters/resolveRef")
local types = require("@root/types")

type Source = types.Source

local SOURCES: { Source } = {
	{ id = "gh-enterprise", kind = "github", host = "github.example.com" },
	{ id = "jira", kind = "jira", browse = "https://jira.example.com/browse" },
}

test.case("every documented ref form resolves its example to its key", function(assert)
	for _, form in refForms do
		assert.eq(resolveRef(form.example, SOURCES).ref.key, form.key)
	end
end)

test.case("each form's adapter has the parser the form needs", function(assert)
	for _, form in refForms do
		local kind = form.kind

		if kind then
			local adapter = getAdapter(kind)
			local isUrl = form.example:match("^https?://") ~= nil
			assert.eq(if isUrl then adapter.refFromUrl ~= nil else adapter.refFromKey ~= nil, true)
		end
	end
end)
