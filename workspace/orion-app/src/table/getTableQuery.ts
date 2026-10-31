import type { QueryRequest } from '../persist'

/** Leaves out groups and images, which the table doesn't list. */
const CARDS = 'kind != "group" and kind != "image"'

/**
 * The query for the Table tab: every card inside `root` at any depth, or on the whole canvas when `root` is null, done
 * ones included, sorted by the group they sit in and then by label.
 */
export function getTableQuery(root: string | null): QueryRequest {
  return { where: root ? `within = ${JSON.stringify(root)} and ${CARDS}` : CARDS, sort: 'group,label', all: true }
}
