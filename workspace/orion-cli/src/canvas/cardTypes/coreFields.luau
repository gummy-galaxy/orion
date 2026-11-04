-- Card types declare these four fields like any other. Other fields keep their
-- values under `data.fields`, but these stay directly on `data`, where cards
-- stored them before types existed. Each is set with an option of its own, such
-- as `--who`, rather than `--field`.
local coreFields: { [string]: boolean } = { who = true, repo = true, shape = true, color = true }

return table.freeze(coreFields)
