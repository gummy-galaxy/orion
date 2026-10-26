--[[
	Applies the repository settings that GitHub allows only once the repository
	is public: the ruleset whose checks every pull request into the default
	branch must pass, approval before an outside contributor's workflows run,
	and the orion-admins team as the reviewer a fork's perf run waits on before
	it runs on artemis. Run it from a checkout with an admin's `gh` login after
	going public, and again after changing anything below. It updates what it
	set before rather than adding to it.

	lute run repository-settings
]]
local json = require("@std/json")

local command = require("@cli/command")
local runScript = require("@cli/runScript")

-- The checks every pull request into the default branch must pass. A required
-- check matches a job's name alone. storybook-publish stays optional because
-- its workflow skips by `paths`, so it never reports on pull requests that
-- don't touch the app. docs-deploy and perf-report publish rather than check.
local REQUIRED_CHECKS = {
	"ci-loading",
	"cli-analysis",
	"cli (ubuntu-latest)",
	"app",
	"desktop (ubuntu-latest)",
	"changelog",
	"docs-loading",
	"docs",
	"perf-loading",
	"perf",
}

local RULESET_NAME = "Default branch"
local ADMIN_TEAM = "orion-admins"
local FORK_ENVIRONMENT = "perf-fork"
-- GitHub Actions' app ID, so only Actions can report a required check.
local ACTIONS_APP_ID = 15368

local function gh(argv: { string }, body: json.Value?): string
	local result = command({ "gh", table.unpack(argv) }, if body ~= nil then json.serialize(body) else nil)
	assert(result.ok, `gh {table.concat(argv, " ")} failed: {result.stderr}`)
	return (result.stdout:gsub("%s+$", ""))
end

runScript(function()
	local repository = gh({ "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner" })
	local owner = assert(repository:match("^[^/]+"), `{repository} has no owner`)

	gh({
		"api",
		"-X",
		"PUT",
		`repos/{repository}/actions/permissions/fork-pr-contributor-approval`,
		"-f",
		"approval_policy=all_external_contributors",
	})
	print("Outside contributors' workflows wait for approval")

	local teamId = tonumber(gh({ "api", `orgs/{owner}/teams/{ADMIN_TEAM}`, "--jq", ".id" }))
	gh(
		{ "api", "-X", "PUT", `repos/{repository}/environments/{FORK_ENVIRONMENT}`, "--input", "-" },
		json.object({ reviewers = { json.object({ type = "Team", id = teamId }) } })
	)
	print(`{FORK_ENVIRONMENT} waits for {ADMIN_TEAM}`)

	local checks = {}
	for _, check in REQUIRED_CHECKS do
		table.insert(checks, json.object({ context = check, integration_id = ACTIONS_APP_ID }))
	end

	local ruleset = json.object({
		name = RULESET_NAME,
		target = "branch",
		enforcement = "active",
		conditions = json.object({
			ref_name = json.object({ include = { "~DEFAULT_BRANCH" }, exclude = {} }),
		}),
		rules = {
			json.object({
				type = "required_status_checks",
				parameters = json.object({
					strict_required_status_checks_policy = false,
					required_status_checks = checks,
				}),
			}),
		},
	})

	local existing = gh({
		"api",
		`repos/{repository}/rulesets`,
		"--jq",
		`.[] | select(.name == "{RULESET_NAME}") | .id`,
	})
	if existing == "" then
		gh({ "api", "-X", "POST", `repos/{repository}/rulesets`, "--input", "-" }, ruleset)
	else
		gh({ "api", "-X", "PUT", `repos/{repository}/rulesets/{existing}`, "--input", "-" }, ruleset)
	end
	print(`{RULESET_NAME} requires {#REQUIRED_CHECKS} checks`)
end)
