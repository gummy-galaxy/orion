local test = require("@std/test")

local parseTranscript = require("@root/adapters/claude/parseTranscript")

local function line(entry: string): string
	return entry .. "\n"
end

local PROMPT = line(
	'{"type":"user","gitBranch":"agent/a","cwd":"/work","timestamp":"2026-10-18T10:00:00Z","message":{"role":"user",'
		.. '"content":"Fix the bug"}}'
)
local REMINDER = line(
	'{"type":"user","gitBranch":"agent/a","cwd":"/work","message":{"role":"user",'
		.. '"content":"<system-reminder>x</system-reminder>"}}'
) .. line(
	'{"type":"user","gitBranch":"agent/a","cwd":"/work","message":{"role":"user",'
		.. '"content":"<system-reminder>y</system-reminder>\\nAnd add a test"}}'
)
local TOOL_CALL = line(
	'{"type":"assistant","gitBranch":"agent/a","cwd":"/work","message":{"stop_reason":"tool_use",'
		.. '"content":[{"type":"text","text":"Running tests."},{"type":"tool_use","name":"Bash"}]}}'
)
local TOOL_RESULT =
	line('{"type":"user","gitBranch":"agent/a","cwd":"/work","message":{"content":[{"type":"tool_result"}]}}')
local FINISHED = line(
	'{"type":"assistant","gitBranch":"agent/a","cwd":"/work","timestamp":"2026-10-18T10:05:00Z",'
		.. '"message":{"stop_reason":"end_turn","content":[{"type":"text","text":"Fixed and pushed."}]}}'
)
local INTERRUPTED = line(
	'{"type":"user","gitBranch":"agent/a","cwd":"/work","message":{"content":[{"type":"text",'
		.. '"text":"[Request interrupted by user]"}]}}'
)

test.case("a finished turn is your move, with its last message and prose-only turns", function(assert)
	local transcript = parseTranscript(
		PROMPT
			.. REMINDER
			.. TOOL_CALL
			.. TOOL_RESULT
			.. FINISHED
			.. line('{"type":"custom-title","customTitle":"Bug fix"}')
	)

	assert.eq(transcript.state, "waiting")
	assert.eq(transcript.branch, "agent/a")
	assert.eq(transcript.cwd, "/work")
	assert.eq(transcript.title, "Bug fix")
	assert.eq(transcript.lastMessage, "Fixed and pushed.")
	assert.eq(transcript.lastAt, "2026-10-18T10:05:00Z")
	assert.eq(#transcript.turns, 4)
	assert.eq(transcript.turns[1].text, "Fix the bug")
	assert.eq(transcript.turns[1].role, "you")
	assert.eq(transcript.turns[2].text, "And add a test")
	assert.eq(transcript.turns[4].text, "Fixed and pushed.")
	assert.eq(transcript.turns[4].role, "agent")
end)

test.case("a tool call with no result or an interrupt is your move, and a result is working", function(assert)
	assert.eq(parseTranscript(PROMPT).state, "working")
	assert.eq(parseTranscript(PROMPT .. TOOL_CALL).state, "waiting")
	assert.eq(parseTranscript(PROMPT .. TOOL_CALL .. TOOL_RESULT).state, "working")
	assert.eq(parseTranscript(PROMPT .. INTERRUPTED).state, "waiting")
end)

test.case("an agent name titles a session that has no custom title", function(assert)
	assert.eq(parseTranscript(PROMPT .. line('{"type":"agent-name","agentName":"Fixer"}')).title, "Fixer")
end)

test.case("broken lines and sidechains are skipped", function(assert)
	local sidechain = line(
		'{"type":"assistant","isSidechain":true,"gitBranch":"other","message":{"stop_reason":"end_turn",'
			.. '"content":[{"type":"text","text":"sub"}]}}'
	)
	local transcript = parseTranscript("{not json\n" .. PROMPT .. sidechain)

	assert.eq(transcript.branch, "agent/a")
	assert.eq(transcript.state, "working")
	assert.eq(#transcript.turns, 1)
end)
