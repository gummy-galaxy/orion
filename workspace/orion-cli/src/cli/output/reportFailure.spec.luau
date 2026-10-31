local json = require("@std/json")
local test = require("@std/test")

local raiseFailure = require("@root/common/errors/raiseFailure")
local reportFailure = require("@root/cli/output/reportFailure")

type Printed = { stdout: { string }, stderr: { string } }

local function report(args: { string }, failure: unknown): Printed
	local printed: Printed = { stdout = {}, stderr = {} }

	reportFailure(args, failure, function(line: string)
		table.insert(printed.stdout, line)
	end, function(line: string)
		table.insert(printed.stderr, line)
	end)

	return printed
end

local function getError(line: string): json.Object?
	local value = json.asObject(json.deserialize(line))
	return if value then json.asObject(value.error) else nil
end

test.case("a failure under --json prints its code and message as a JSON error on stdout", function(assert)
	local _, failure = pcall(raiseFailure, "missing-item", 'no item or group with id "missing"')
	local printed = report({ "node", "show", "missing", "--json" }, failure)
	local error = getError(printed.stdout[1])

	assert.eq(#printed.stderr, 0)
	assert.eq(error and error.code, "missing-item")
	assert.eq(error and error.message, 'no item or group with id "missing"')
end)

test.case("a failure without a code leaves it out of the JSON error", function(assert)
	local _, failure = pcall(error, "bad plan")
	local error = getError(report({ "apply", "--json" }, failure).stdout[1])

	assert.eq(error and error.code, nil)
	assert.eq(error and error.message, "bad plan")
end)

test.case("a failure without --json prints an Error: line on stderr and nothing on stdout", function(assert)
	local _, failure = pcall(raiseFailure, "missing-item", "no such item")
	local printed = report({ "node", "show", "missing" }, failure)

	assert.eq(printed.stdout, {})
	assert.eq(printed.stderr, { "Error: no such item" })
end)

test.case("--json after -- is passed along rather than asking for JSON", function(assert)
	assert.eq(report({ "apply", "--", "--json" }, "bad plan").stderr, { "Error: bad plan" })
end)
