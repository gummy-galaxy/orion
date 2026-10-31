export type Group = { id: string, title: string, members: { string }, reason: string, source: string }
-- createdAt is absent until suggestions have been found.
export type Result = { createdAt: string?, groups: { Group } }

return table.freeze({})
