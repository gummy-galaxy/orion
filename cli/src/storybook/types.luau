-- One story from Storybook's index.json. `file` is its stories file from the repository root, and `order` is where its
-- export sits in that file, which is the order Storybook lists a component's stories in.
export type Story = { id: string, name: string, title: string, file: string, order: number }

-- Returns a file's contents by its path from the repository root, or nil when there's no such file.
export type ReadFile = (path: string) -> string?

return table.freeze({})
