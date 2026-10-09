export function getRepositoryColorIndex(repository: string): number {
  let hash = 0

  for (let index = 0; index < repository.length; index++) {
    hash = (Math.imul(hash, 31) + repository.charCodeAt(index)) >>> 0
  }

  return hash % 4
}
