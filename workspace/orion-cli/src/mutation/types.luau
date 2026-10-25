-- One change to a module's source, located by where it starts.
export type Mutation = {
	line: number,
	column: number,
	original: string,
	replacement: string,
	source: string,
}

-- What became of a mutation once its module's spec ran against it.
export type Outcome = "killed" | "survived" | "timedOut"

return {}
