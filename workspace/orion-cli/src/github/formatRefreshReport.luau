local githubTypes = require("@root/github/types")

-- Describes what a pull request refresh changed, for `orion ingest`.
local function formatRefreshReport(report: githubTypes.Report, isDryRun: boolean): string
	local lines = { `{if isDryRun then "Would update" else "Checked"} {report.checked} pull requests on GitHub.` }

	for _, change in report.changes do
		local who = if change.fromWho ~= change.toWho
			then ` (move: {change.fromWho or "unset"} → {change.toWho or "unset"})`
			else ""
		local closed = if change.closed
			then " — closed without merging; deferred until it reopens or you decide"
			else ""
		table.insert(lines, `  {change.id}: {change.fromStatus} → {change.toStatus}{who}{closed}`)
	end

	if #report.changes == 0 and #report.attached == 0 and #report.linked == 0 and #report.unlinked == 0 then
		table.insert(lines, "  Everything already matches.")
	end

	for _, attachment in report.attached do
		table.insert(lines, `  attached {attachment.pull} to {attachment.id} (from its branch)`)
	end

	for _, link in report.linked do
		table.insert(lines, `  linked {link.from} → {link.to} (stacked)`)
	end

	for _, link in report.unlinked do
		table.insert(lines, `  unlinked {link.from} → {link.to} (stacked)`)
	end

	if #report.missing > 0 then
		table.insert(lines, `  not found on GitHub: {table.concat(report.missing, ", ")}`)
	end

	for _, failure in report.failures do
		table.insert(lines, `  couldn't fetch {failure}`)
	end

	return table.concat(lines, "\n")
end

return formatRefreshReport
