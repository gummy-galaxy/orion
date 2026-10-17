export type Group = { id: string, title: string, members: { string }, reason: string, source: string }
export type Result = { createdAt: string, groups: { Group } }

return table.freeze({})
