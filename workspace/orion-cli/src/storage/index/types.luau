-- Raised by `runSqlite` when `sqlite3` reports an error. `isCorrupt` means the
-- database file is damaged or isn't a database, so an index can be deleted and
-- built again.
export type SqliteFailure = { message: string, isCorrupt: boolean }

return nil
