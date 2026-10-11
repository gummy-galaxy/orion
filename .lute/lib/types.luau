export type Job = {
	name: string,
	status: string,
	conclusion: string?,
}

export type Run = {
	id: string,
	status: string,
	conclusion: string?,
}

export type WatchDecision = {
	stop: boolean,
	reason: string,
}

return {}
