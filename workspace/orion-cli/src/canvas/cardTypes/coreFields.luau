-- Fields Orion's shipped types keep on the card itself, as they did before
-- types, rather than under `data.fields`. Each has an option of its own, such
-- as `--who`.
local coreFields: { [string]: boolean } = { who = true, repo = true, shape = true, color = true }

return table.freeze(coreFields)
