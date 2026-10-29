local json = require("@std/json")
local test = require("@std/test")

local presets = require("@root/sessions/presets")
local testing = require("@root/testing")

local function getPreset(id: string)
	for _, preset in presets do
		if preset.id == id then
			return preset
		end
	end

	error(`no preset {id}`)
end

local function card(readiness: string?)
	return testing.task("fix", "Fix the flaky test", "active", nil, {
		repo = "owner/repo",
		note = "It fails on Windows.",
		refs = {
			json.object({
				source = "github",
				kind = "pull",
				key = "owner/repo#12",
				url = "https://github.com/owner/repo/pull/12",
				readiness = readiness,
			}),
			json.object({ source = "claude", kind = "session", key = "Earlier work" }),
		},
	})
end

test.case("work fits every card and asks for the card's work", function(assert)
	local work = getPreset("work")
	local prompt = work.buildPrompt(card(), "agent/fix")

	assert.eq(work.appliesTo(card()), true)
	assert.eq(work.appliesTo(testing.group("g", "Group")), false)
	assert.strContains(prompt, "Fix the flaky test")
	assert.strContains(prompt, "It fails on Windows.")
	assert.strContains(prompt, "- https://github.com/owner/repo/pull/12")
	assert.strContains(prompt, "agent/fix")
	assert.eq(prompt:find("Earlier work", 1, true), nil)
end)

test.case("resolve conflicts fits only a pull request with conflicts", function(assert)
	local resolve = getPreset("resolve-conflicts")
	local prompt = resolve.buildPrompt(card("conflict"), "agent/fix")

	assert.eq(resolve.appliesTo(card("conflict")), true)
	assert.eq(resolve.appliesTo(card("passing")), false)
	assert.eq(resolve.appliesTo(card()), false)
	assert.strContains(prompt, "https://github.com/owner/repo/pull/12 has merge conflicts")
	assert.strContains(prompt, "into agent/fix, without rebasing or force-pushing")
end)
