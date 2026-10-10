#!/bin/sh
# Turns a spare Mac into the self-hosted runner the Perf workflow uses when PERF_RUNS_ON is ["self-hosted","perf"].
# Run it once on that Mac, signed in to `gh` as a repository admin. It asks for your password to keep the Mac awake.
set -eu

repo=vocksel/orion
dir="$HOME/actions-runner"

version=$(gh api repos/actions/runner/releases/latest --jq '.tag_name | ltrimstr("v")')
token=$(gh api -X POST "repos/$repo/actions/runners/registration-token" --jq .token)

mkdir -p "$dir"
cd "$dir"

if [ ! -x ./config.sh ]; then
  curl -fsSL "https://github.com/actions/runner/releases/download/v$version/actions-runner-osx-arm64-$version.tar.gz" | tar xz
fi

./config.sh --unattended --replace --url "https://github.com/$repo" --token "$token" --name "$(scutil --get LocalHostName)" --labels perf
./svc.sh install
./svc.sh start

# Stay awake with the lid closed, and come back on after a power cut.
sudo pmset -a sleep 0 disksleep 0 disablesleep 1 autorestart 1

cat <<EOF

The runner is installed and running as $(whoami). It starts when you log in, so turn on automatic login in
System Settings › Users & Groups (FileVault has to be off) to have it come back on its own after a restart.

Since the Mac stays plugged in, cap its charge with a tool such as batt to spare the battery.

To send perf runs here, run:
  gh variable set PERF_RUNS_ON --repo $repo --body '["self-hosted","perf"]'
EOF
