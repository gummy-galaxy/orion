local types = require("@root/prioritize/types")

type Job = types.Job

-- Reads the output of `gh api ... --jq '.jobs[] | [.name, .status, (.conclusion // "")] | @tsv'`, one job per line.
local function parseJobs(output: string): { Job }
	local jobs: { Job } = {}

	for line in string.gmatch(output, "[^\n]+") do
		local name, status, conclusion = string.match(line, "^([^\t]+)\t([^\t]+)\t(.*)$")

		if name and status and conclusion then
			table.insert(jobs, {
				name = name,
				status = status,
				conclusion = if conclusion ~= "" then conclusion else nil,
			})
		end
	end

	return jobs
end

return parseJobs
