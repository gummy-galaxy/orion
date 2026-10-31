local graphTypes = require("@root/canvas/types")
local types = require("@root/types")

-- What a query reads nodes against: the derived graph, and each group's
-- labels from the top level down to it, by id.
export type Scope = {
	derived: graphTypes.Derived,
	groupPaths: { [string]: { string } },
}

-- One key to sort by. Ties fall to the next key, then to canvas order.
export type Sort = { field: string, isDescending: boolean }

-- What queryItems selects and how it pages. A missing `where` matches every
-- node, and a missing `limit` returns the rest after `offset`.
export type Query = {
	where: string?,
	sort: { Sort }?,
	offset: number?,
	limit: number?,
	includeDone: boolean?,
	now: string?,
}

-- One page of matches. `total` counts every match before paging, and
-- `derived` is the graph the matches were read from, for rendering them.
export type Result = {
	total: number,
	offset: number,
	items: { types.Item },
	derived: graphTypes.Derived,
}

return nil
