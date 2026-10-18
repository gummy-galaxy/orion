local getRefs = require("@root/refs/getRefs")
local setPullFacts = require("@root/github/setPullFacts")
local types = require("@root/types")

type Item = types.Item

-- Gives pull request refs recorded before refs carried source-neutral facts the facts their details support. A
-- refresh sets them on open pull requests, but merged ones are never fetched again.
local function fillPullFacts(item: Item)
	for _, ref in getRefs(item) do
		if ref.kind == "pull" and ref.details and ref.checkedAt == nil and ref.details.checkedAt ~= nil then
			setPullFacts(ref, ref.details)
		end
	end
end

return fillPullFacts
