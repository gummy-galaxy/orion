local aliasTypes = require("@root/aliases/types")

type Alias = aliasTypes.Alias

-- Every alias in this release, each with a row in README.md. Each release
-- removes the ones from before it.
local entries: { Alias } = {
	{ kind = "command", from = "card add", to = "card create", added = "2026-10-21", pr = 566 },
	{ kind = "command", from = "note add", to = "note create", added = "2026-10-21", pr = 566 },
	{ kind = "command", from = "link add", to = "link create", added = "2026-10-21", pr = 566 },
	{ kind = "command", from = "group add", to = "group create", added = "2026-10-21", pr = 566 },
	{ kind = "command", from = "media insert", to = "media add", added = "2026-10-21", pr = 566 },
	{ kind = "command", from = "backup list", to = "history list", added = "2026-10-26", pr = 668 },
	{ kind = "command", from = "backup restore", to = "history set", added = "2026-10-26", pr = 668 },
}

return table.freeze(entries)
