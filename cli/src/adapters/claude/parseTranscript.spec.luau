local test = require("@std/test")

local parseTranscript = require("@root/adapters/claude/parseTranscript")

local function line(entry: string): string
	return entry .. "\n"
end

local PROMPT = line(
	'{"type":"user","gitBranch":"agent/a","cwd":"/work","timestamp":"2026-10-18T10:00:00Z","message":{"role":"user","content":"Fix the bug"}}'
)
local REMINDER = line(
	'{"type":"user","gitBranch":"agent/a","cwd":"/work","message":{"role":"user","content":"<system-reminder>x</system-reminder>"}}'
) .. line(
	'{"type":"user","gitBranch":"agent/a","cwd":"/work","message":{"role":"user","content":"<system-reminder>y</system-reminder>\\nAnd add a test"}}'
)
local TOOL_CALL = line(
	'{"type":"assistant","gitBranch":"agent/a","cwd":"/work","message":{"stop_reason":"tool_use","content":[{"type":"text","text":"Running tests."},{"type":"tool_use","name":"Bash"}]}}'
)
local TOOL_RESULT =
	line('{"type":"user","gitBranch":"agent/a","cwd":"/work","message":{"content":[{"type":"tool_result"}]}}')
local FINISHED = line(
	'{"type":"assistant","gitBranch":"agent/a","cwd":"/work","timestamp":"2026-10-18T10:05:00Z","message":{"stop_reason":"end_turn","content":[{"type":"text","text":"Fixed and pushed."}]}}'
)

test.case("a finished turn reads as done with its last message and prose-only turns", function(assert)
	local transcript = parseTranscript(
		PROMPT
			.. REMINDER
			.. TOOL_CALL
			.. TOOL_RESULT
			.. FINISHED
			.. line('{"type":"custom-title","customTitle":"Bug fix"}')
	)

	assert.eq(transcript.state, "done")
	assert.eq(transcript.branch, "agent/a")
	assert.eq(transcript.title, "Bug fix")
	assert.eq(transcript.lastMessage, "Fixed and pushed.")
	assert.eq(#transcript.turns, 4)
	assert.eq(transcript.turns[1].text, "Fix the bug")
	assert.eq(transcript.turns[2].text, "And add a test")
	assert.eq(transcript.turns[4].text, "Fixed and pushed.")
end)

test.case("a tool call with no result reads as waiting, and a result as working", function(assert)
	assert.eq(parseTranscript(PROMPT .. TOOL_CALL).state, "waiting")
	assert.eq(parseTranscript(PROMPT .. TOOL_CALL .. TOOL_RESULT).state, "working")
end)

test.case("broken lines and sidechains are skipped", function(assert)
	local sidechain = line(
		'{"type":"assistant","isSidechain":true,"gitBranch":"other","message":{"stop_reason":"end_turn","content":[{"type":"text","text":"sub"}]}}'
	)
	local transcript = parseTranscript("{not json\n" .. PROMPT .. sidechain)

	assert.eq(transcript.branch, "agent/a")
	assert.eq(transcript.state, "working")
	assert.eq(#transcript.turns, 1)
end)
