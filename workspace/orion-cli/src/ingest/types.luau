local adapterTypes = require("@root/adapters/types")
local githubTypes = require("@root/github/types")
local types = require("@root/types")

type Record = adapterTypes.Record
type Source = types.Source

export type SourceReport = { id: string, added: number, updated: number, linked: number, failed: string? }
-- What one adapter's refresh of the cards already on the canvas changed, or why
-- it failed.
export type RefreshReport = { kind: string, report: githubTypes.Report?, failed: string? }
export type Report = { sources: { SourceReport }, refreshes: { RefreshReport }? }
export type Result = { source: Source, report: SourceReport, records: { Record }?, order: number? }

return {}
