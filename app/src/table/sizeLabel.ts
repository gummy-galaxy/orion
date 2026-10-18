/** A pull request's size from the lines it changes, in the buckets reviewers use. */
export function sizeLabel(lines: number): string {
  if (lines < 10) return 'XS'

  if (lines < 100) return 'S'

  if (lines < 400) return 'M'

  if (lines < 1000) return 'L'

  return 'XL'
}
