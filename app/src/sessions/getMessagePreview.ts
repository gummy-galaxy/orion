/** A Markdown message as one line of plain text for a card: links keep their words, and code and emphasis marks drop. */
export function getMessagePreview(message: string): string {
  return message
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/^\s*[#>]+\s*/gm, '')
    .replace(/[`*_]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
}
