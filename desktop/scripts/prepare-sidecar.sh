#!/bin/sh
set -eu

desktop_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
repo_dir=$(CDPATH= cd -- "$desktop_dir/.." && pwd)
target_triple=$(rustc -vV | sed -n 's/^host: //p')

if [ -z "$target_triple" ]; then
  echo 'Could not determine the Rust host target triple' >&2
  exit 1
fi

(cd "$repo_dir/cli" && lute run build)
mkdir -p "$desktop_dir/src-tauri/binaries"
cp "$repo_dir/cli/build/orion" "$desktop_dir/src-tauri/binaries/orion-$target_triple"
