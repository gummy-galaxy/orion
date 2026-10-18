/** The `owner/name` a pull request key such as `owner/name#12`, or `host/owner/name#12`, belongs to. */
export function getPullRepo(key: string): string | undefined {
  return key.match(/([^/]+\/[^/#]+)#\d+$/)?.[1]
}
