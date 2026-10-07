#!/bin/sh
set -eu

desktop_directory=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
repository_directory=$(CDPATH= cd -- "$desktop_directory/.." && pwd)
target_triple=$(rustc -vV | sed -n 's/^host: //p')

if [ -z "$target_triple" ]; then
  echo 'Could not determine the Rust host target triple' >&2
  exit 1
fi

(cd "$repository_directory/cli" && lute run build)
mkdir -p "$desktop_directory/src-tauri/binaries"
cp "$repository_directory/cli/build/orion" "$desktop_directory/src-tauri/binaries/orion-$target_triple"
