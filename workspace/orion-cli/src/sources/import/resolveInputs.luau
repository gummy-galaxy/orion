local getErrorText = require("@root/common/errors/getErrorText")
local getRefKey = require("@root/sources/getRefKey")
local importTypes = require("@root/sources/import/types")
local resolveRef = require("@root/sources/resolveRef")
local types = require("@root/types")

type Entry = importTypes.Entry
type Source = types.Source

-- Resolves each input with the same grammar as --ref. An input that doesn't
-- resolve, or repeats an earlier one, becomes an entry with an error instead of
-- a ref.
local function resolveInputs(inputs: { string }, sources: { Source }): { Entry }
	local entries: { Entry } = {}
	local seen: { [string]: boolean } = {}

	for _, input in inputs do
		local succeeded, resolved = pcall(resolveRef, input, sources)

		if not succeeded then
			table.insert(entries, { input = input, error = getErrorText(resolved) })
			continue
		end

		local key = getRefKey(resolved.ref)

		if seen[key] then
			table.insert(entries, { input = input, error = "listed more than once" })
		else
			seen[key] = true
			table.insert(entries, { input = input, resolved = resolved })
		end
	end

	return entries
end

return resolveInputs
