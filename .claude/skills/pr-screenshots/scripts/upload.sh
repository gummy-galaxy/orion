#!/bin/sh
# Commits images to the media branch without checking it out and prints a
# Markdown image link for each one. Run it from inside the repository.
#
#   upload.sh <pr number> <image>...
#
# Images land in pr-<number>/ on agent/pr-media. Links point at the new commit,
# so they keep working when the same file name is uploaded again later.

set -eu

if [ "$#" -lt 2 ]; then
  echo "usage: upload.sh <pr number> <image>..." >&2
  exit 1
fi

number=$1
shift

branch=${PR_MEDIA_BRANCH:-agent/pr-media}
repository=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
index=$(mktemp)
trap 'rm -f "$index"' EXIT

for attempt in 1 2 3; do
  if git fetch --quiet origin "refs/heads/$branch" 2>/dev/null; then
    parent=$(git rev-parse FETCH_HEAD)
    GIT_INDEX_FILE=$index git read-tree "$parent"
  else
    parent=
    GIT_INDEX_FILE=$index git read-tree --empty
    readme=$(printf '%s\n' \
      '# PR media' '' \
      'Screenshots for pull request descriptions, one folder per pull request.' \
      'Nothing here is merged. Pull requests link to these files by commit.' |
      git hash-object -w --stdin)
    GIT_INDEX_FILE=$index git update-index --add --cacheinfo "100644,$readme,README.md"
  fi

  for file in "$@"; do
    blob=$(git hash-object -w "$file")
    GIT_INDEX_FILE=$index git update-index --add --cacheinfo "100644,$blob,pr-$number/$(basename "$file")"
  done

  tree=$(GIT_INDEX_FILE=$index git write-tree)

  if [ -n "$parent" ]; then
    commit=$(git commit-tree "$tree" -p "$parent" -m "Add screenshots for #$number")
  else
    commit=$(git commit-tree "$tree" -m "Add screenshots for #$number")
  fi

  if git push --quiet origin "$commit:refs/heads/$branch"; then
    for file in "$@"; do
      name=$(basename "$file")
      echo "![${name%.*}](https://github.com/$repository/blob/$commit/pr-$number/$name?raw=true)"
    done

    exit 0
  fi

  echo "Push to $branch was rejected, retrying ($attempt)" >&2
done

echo "Could not push to $branch" >&2
exit 1
