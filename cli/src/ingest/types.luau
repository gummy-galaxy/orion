local adapterTypes = require("@root/adapters/types")
local types = require("@root/types")

type Record = adapterTypes.Record
type Source = types.Source

export type SourceReport = { id: string, added: number, updated: number, linked: number, failed: string? }
export type Report = { sources: { SourceReport } }
export type Result = { source: Source, report: SourceReport, records: { Record }?, order: number? }

return {}
