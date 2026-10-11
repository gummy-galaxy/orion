local test = require("@std/test")

local resolveRef = require("@root/adapters/resolveRef")
local types = require("@root/types")

type Source = types.Source

local ENTERPRISE: Source = { id = "gh-roblox", kind = "github", host = "github.example.com", owners = { "Roblox" } }
local JIRA: Source = {
	id = "jira",
	kind = "jira",
	command = { "acli", "jira", "workitem", "search" },
	browse = "https://jira.example.com/browse",
}
local HOP: Source = { id = "hop", kind = "hop", command = { "hop" } }

test.case("a github.com pull request URL attaches without a configured source", function(assert)
	local resolved = resolveRef("https://github.com/Roblox/avatar/pull/12", {})
	assert.eq(resolved.ref.source, "github")
	assert.eq(resolved.ref.kind, "pull")
	assert.eq(resolved.ref.key, "Roblox/avatar#12")
	assert.eq(resolved.ref.url, "https://github.com/Roblox/avatar/pull/12")
	assert.eq(resolved.repo, "Roblox/avatar")
end)

test.case("a GitHub issue URL on a configured host uses that source and keeps the host in the key", function(assert)
	local resolved = resolveRef("https://github.example.com/Roblox/avatar/issues/3", { ENTERPRISE })
	assert.eq(resolved.ref.source, "gh-roblox")
	assert.eq(resolved.ref.kind, "issue")
	assert.eq(resolved.ref.key, "github.example.com/Roblox/avatar#3")
	assert.eq(resolved.repo, "Roblox/avatar")
end)

test.case("a GitHub URL on a host without a configured source is refused", function(assert)
	assert.throwsWith(
		"no source recognizes https://git.example.org/Roblox/avatar/pull/1; add its GitHub or Jira source first, or use source:key",
		resolveRef,
		"https://git.example.org/Roblox/avatar/pull/1",
		{}
	)
end)

test.case("a URL that is not an issue or pull request is refused", function(assert)
	assert.throws(function()
		resolveRef("https://github.com/Roblox/avatar/tree/main", {})
	end)
end)

test.case("a Jira URL under a configured browse address attaches the issue", function(assert)
	local resolved = resolveRef("https://jira.example.com/browse/ABC-12", { JIRA })
	assert.eq(resolved.ref.source, "jira")
	assert.eq(resolved.ref.kind, "issue")
	assert.eq(resolved.ref.key, "ABC-12")
	assert.eq(resolved.ref.url, "https://jira.example.com/browse/ABC-12")
	assert.eq(resolved.repo, nil)
end)

test.case("a Jira URL needs a source with that browse address and a Jira-shaped key", function(assert)
	assert.throws(function()
		resolveRef("https://jira.example.com/browse/ABC-12", {})
	end)
	assert.throws(function()
		resolveRef("https://jira.example.com/browse/abc-12", { JIRA })
	end)
end)

test.case("source:key attaches a Jira issue through its configured source", function(assert)
	local resolved = resolveRef("jira:ABC-12", { JIRA })
	assert.eq(resolved.ref.source, "jira")
	assert.eq(resolved.ref.key, "ABC-12")
	assert.eq(resolved.ref.url, "https://jira.example.com/browse/ABC-12")
end)

test.case("source:key refuses GitHub and hop, which need a URL or no attach at all", function(assert)
	assert.throwsWith(
		"github sources can't attach refs with source:key; use a URL",
		resolveRef,
		"gh-roblox:Roblox/avatar#12",
		{ ENTERPRISE }
	)
	assert.throwsWith("hop sources can't attach refs with source:key; use a URL", resolveRef, "hop:branch", { HOP })
end)

test.case("source:key names a source that is configured", function(assert)
	assert.throwsWith('no source with id "missing"', resolveRef, "missing:ABC-12", { JIRA })
	assert.throwsWith('"not-a-key" is not a valid jira key', resolveRef, "jira:not-a-key", { JIRA })
end)

test.case("input that is neither a URL nor source:key is refused", function(assert)
	assert.throws(function()
		resolveRef("ABC-12", { JIRA })
	end)
	assert.throws(function()
		resolveRef("", { JIRA })
	end)
end)
