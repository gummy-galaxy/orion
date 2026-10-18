--[[
	Mutation-tests Luau modules: makes one small change at a time to a module, such as flipping `==` to `~=`, and runs
	the module's sibling spec against it. A change the spec still passes with is a survivor, a spot where the tests
	don't pin the behavior down. The module is restored after every run, and on Ctrl-C.

	lute run mutate src/store/pruneBackups.luau [src/graph.luau ...] [--spec <spec or folder>]...

	Repeat --spec, or pass a folder such as src/cli, to count tests outside the sibling spec. Every module is checked
	against the same specs then.
]]
local fs = require("@std/fs")
local process = require("@std/process")
local time = require("@std/time")

local findMutations = require("@root/mutation/findMutations")
local mutationTypes = require("@root/mutation/types")

local runScript = require("@root/runScript")

type Mutation = mutationTypes.Mutation
type Outcome = mutationTypes.Outcome

-- Runs a command, killing it if it outlasts the given seconds, as a mutation that loops forever would.
local WATCHDOG = [[
seconds=$1
shift
"$@" > /dev/null 2>&1 &
child=$!
(sleep "$seconds"; kill -9 "$child") > /dev/null 2>&1 &
watchdog=$!
wait "$child"
status=$?
kill "$watchdog" 2> /dev/null
exit "$status"
]]
local KILLED_EXIT_CODE = 137

local lute = tostring(process.execPath())

local function runSpecs(specs: { string }, timeoutSeconds: number): Outcome
	local result =
		process.run({ "sh", "-c", WATCHDOG, "sh", tostring(timeoutSeconds), lute, "test", table.unpack(specs) })

	if result.ok then
		return "survived"
	end

	return if result.exitcode == KILLED_EXIT_CODE then "timedOut" else "killed"
end

runScript(function()
	local modules: { string } = {}
	local specOverrides: { string } = {}
	local index = 2

	while index <= #process.args do
		local argument = process.args[index]

		if argument == "--spec" then
			table.insert(specOverrides, (assert(process.args[index + 1], "--spec needs a path")))
			index += 2
		else
			table.insert(modules, argument)
			index += 1
		end
	end

	assert(#modules > 0, "usage: lute run mutate <module.luau>... [--spec <spec or folder>]...")

	local restoring: { file: string, source: string }? = nil

	local interrupt = process.onSignal("SIGINT", function()
		if restoring then
			fs.writeStringToFile(restoring.file, restoring.source)
		end

		process.exit(130)
	end)

	local totalKilled, totalCount = 0, 0

	for _, module in modules do
		local specs = if #specOverrides > 0 then specOverrides else { (module:gsub("%.luau$", ".spec.luau")) }
		local described = table.concat(specs, ", ")

		if not fs.exists(specs[1]) then
			print(`{module}: no spec at {described}, skipped`)
			continue
		end

		local started = time.now()
		assert(runSpecs(specs, 600) == "survived", `{described} fails before any mutation; fix it first`)
		-- Generous, since a mutation can make a spec slower without looping.
		local timeoutSeconds = math.max(10, math.ceil(time.since(started) * 10))

		local original = fs.readFileToString(module)
		local mutations = findMutations(original)
		local survivors: { Mutation } = {}
		local killed = 0
		restoring = { file = module, source = original }

		for _, mutation in mutations do
			fs.writeStringToFile(module, mutation.source)
			local succeeded, outcome = pcall(runSpecs, specs, timeoutSeconds)
			fs.writeStringToFile(module, original)
			assert(succeeded, outcome)

			if outcome == "survived" then
				table.insert(survivors, mutation)
			else
				killed += 1
			end
		end

		restoring = nil
		totalKilled += killed
		totalCount += #mutations
		print(`{module}: {killed} of {#mutations} mutations caught by {described}`)

		for _, mutation in survivors do
			print(`  {module}:{mutation.line}:{mutation.column} {mutation.original} -> {mutation.replacement}`)
		end
	end

	interrupt:close()

	if #modules > 1 then
		print(`Total: {totalKilled} of {totalCount} mutations caught`)
	end
end)
