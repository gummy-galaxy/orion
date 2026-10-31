/** A folder's last name, for showing where a session starts without its whole path. */
export function getFolderName(folder: string | null): string {
  return folder?.split(/[\\/]/).filter(Boolean).pop() ?? 'its folder'
}
