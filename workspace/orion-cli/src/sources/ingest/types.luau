local adapterTypes = require("@root/sources/types")
local githubTypes = require("@root/sources/github/types")
local types = require("@root/types")

type Record = adapterTypes.Record
type Source = types.Source

export type SourceReport = { id: string, added: number, updated: number, linked: number, failed: string? }
-- What one adapter's refresh of the cards already on the canvas changed, or why
-- it failed.
export type RefreshReport = { kind: string, report: githubTypes.Report?, failed: string? }
export type Report = { sources: { SourceReport }, refreshes: { RefreshReport }? }
-- What session collection remembers between calls: each folder's repository,
-- or false when it has none, and the adapter's own cache.
export type SessionCache = { repos: { [string]: string | false }, agent: { [string]: any } }
export type Result = { source: Source, report: SourceReport, records: { Record }?, order: number? }

return nil
