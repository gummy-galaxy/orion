export type Worktree = { repo: string, branch: string, lastActivity: number, onDefault: boolean }
-- A folder hop lists. `primary` marks a repository's main clone.
export type Checkout = { folder: string, repo: string, branch: string?, primary: boolean }
export type Session = { repo: string, branch: string, title: string, updatedAt: number }

return {}
