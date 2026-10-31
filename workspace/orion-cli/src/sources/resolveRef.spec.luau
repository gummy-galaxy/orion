local test = require("@std/test")

local resolveRef = require("@root/sources/resolveRef")
local types = require("@root/types")

type Source = types.Source

local ENTERPRISE: Source = { id = "gh-roblox", kind = "github", host = "github.example.com", owners = { "Roblox" } }
local JIRA: Source = {
	id = "jira",
	kind = "jira",
	browse = "https://jira.example.com/browse",
}
local HOP: Source = { id = "hop", kind = "hop" }

test.case("resolveRef returns only the ref, not an error message as a second value", function(assert)
	assert.eq(select("#", resolveRef("jira:ABC-12", { JIRA })), 1)
	assert.eq(select("#", resolveRef("https://github.com/Roblox/avatar/pull/12", {})), 1)
end)

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
		"no source recognizes https://git.example.org/Roblox/avatar/pull/1; "
			.. "add its GitHub or Jira source first, or use source:key",
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

test.case("branch: records the branch work started on, keyed like hop's branch refs", function(assert)
	local resolved = resolveRef("branch:Roblox/avatar@agent/196-attach", {})
	assert.eq(resolved.ref.source, "github")
	assert.eq(resolved.ref.kind, "branch")
	assert.eq(resolved.ref.key, "Roblox/avatar@agent/196-attach")
	assert.eq(resolved.ref.url, nil)
	assert.eq(resolved.repo, "Roblox/avatar")
end)

test.case("branch: keeps any @ in the branch name after the repository", function(assert)
	local resolved = resolveRef("branch:Roblox/avatar@feature@two", {})
	assert.eq(resolved.ref.key, "Roblox/avatar@feature@two")
end)

test.case("branch: on a configured GitHub host takes the host and the configured source id", function(assert)
	local resolved = resolveRef("branch:github.example.com/Roblox/avatar@main", { ENTERPRISE })
	assert.eq(resolved.ref.source, "gh-roblox")
	assert.eq(resolved.ref.key, "github.example.com/Roblox/avatar@main")
	assert.eq(resolved.repo, "Roblox/avatar")
end)

test.case("branch: on a GitHub host without a configured source is refused", function(assert)
	assert.throwsWith(
		"no GitHub source for git.example.org; add it first",
		resolveRef,
		"branch:git.example.org/Roblox/avatar@main",
		{}
	)
end)

test.case("branch: refuses input that is not owner/name@branch", function(assert)
	for _, input in { "branch:avatar@main", "branch:Roblox/avatar", "branch:Roblox/avatar@", "branch:Roblox/a b@main" } do
		assert.throws(function()
			resolveRef(input, {})
		end)
	end
end)
