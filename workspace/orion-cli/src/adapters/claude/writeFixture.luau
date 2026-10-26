local fs = require("@std/fs")
local json = require("@std/json")

export type Fixture = { branch: string, stop: string, status: string? }

local SESSION = "0b6c3a9e-1111-4222-8333-944455556666"

-- A Claude Code data folder with one transcript and, with a status, the
-- record of the process running it, for specs.
local function writeFixture(dir: string, fixture: Fixture): string
	fs.createDirectory(`{dir}/projects/-work`, { makeParents = true })
	fs.writeStringToFile(
		`{dir}/projects/-work/{SESSION}.jsonl`,
		`\{"type":"user","gitBranch":"{fixture.branch}","cwd":"/work","message":\{"content":"Go"}}\n`
			.. `\{"type":"assistant","gitBranch":"{fixture.branch}","cwd":"/work","message":\{"stop_reason":"{fixture.stop}","content":[\{"type":"text","text":"On it."}]}}\n`
	)

	if fixture.status then
		fs.createDirectory(`{dir}/sessions`, { makeParents = true })
		fs.writeStringToFile(
			`{dir}/sessions/42.json`,
			json.serialize(
				json.object({ pid = 42, sessionId = SESSION, status = fixture.status, name = "Fix the bug" })
			)
		)
		-- Key files sit beside the records and must never be read.
		fs.writeStringToFile(`{dir}/sessions/42.secret.key`, "not json")
	end

	return SESSION
end

return writeFixture
