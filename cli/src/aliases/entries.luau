local aliasTypes = require("@root/aliases/types")

type Alias = aliasTypes.Alias

-- Every alias in this release, each with a row in README.md. Each release removes the ones from before it.
local entries: { Alias } = {}

return table.freeze(entries)
