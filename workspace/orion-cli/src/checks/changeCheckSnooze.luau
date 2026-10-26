local types = require("@root/types")

type Doc = types.Doc

export type Change = {
	repo: string,
	name: string,
	-- Whether the job is snoozed after the change. Unsnoozing a job that isn't
	-- snoozed changes nothing.
	snoozed: boolean,
	untilTime: string?,
	at: string,
}

-- Snoozes a CI job for every card in its repository, or ends its snooze.
-- Snoozing it again replaces the old snooze, so the job starts over on cards
-- where it already passed.
local function changeCheckSnooze(doc: Doc, change: Change)
	assert(change.repo:match("^[^/%s]+/[^/%s]+$"), `"{change.repo}" isn't a repository such as owner/name`)
	assert(change.name ~= "", "a snooze needs the job's name")

	local snoozes = doc.settings.checkSnoozes
	local repo = change.repo:lower()

	for index = #snoozes, 1, -1 do
		local snooze = snoozes[index]

		if snooze.repo:lower() == repo and snooze.name == change.name then
			table.remove(snoozes, index)
		end
	end

	if change.snoozed then
		table.insert(
			snoozes,
			{ repo = change.repo, name = change.name, untilTime = change.untilTime, at = change.at, passed = {} }
		)
	end
end

return changeCheckSnooze
