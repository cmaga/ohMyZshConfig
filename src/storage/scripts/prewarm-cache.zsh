#!/usr/bin/env zsh
#
# prewarm-cache.zsh - Prewarm macOS code signature validation cache.
#
# First launch of any Developer-ID-signed binary on macOS can hang for minutes
# while syspolicyd runs full certificate validation. Subsequent launches of the
# same cdhash hit the kernel trust cache and are instant. This script invokes
# common tools with --version to pay that validation cost in the background,
# once per boot, so interactive use never blocks waiting on it.
#
# Invoked automatically by ~/.zshrc at first shell launch after boot (guarded
# by /tmp sentinel). Can also be run manually:
#   prewarm-cache.zsh &!
#
# Only meaningful on macOS; Linux has no equivalent bottleneck.

[[ "$OSTYPE" == darwin* ]] || exit 0

# Common Developer-ID-signed binaries worth prewarming. Missing ones are skipped.
local -a binaries=(
  /opt/homebrew/bin/gh
  /opt/homebrew/bin/git
  /opt/homebrew/bin/rg
  /opt/homebrew/bin/jq
  /opt/homebrew/bin/fd
  /opt/homebrew/bin/bat
  /opt/homebrew/bin/pnpm
  /opt/homebrew/bin/yarn
  /opt/homebrew/bin/tmux
  /opt/homebrew/bin/docker
  /opt/homebrew/bin/direnv
  /opt/homebrew/bin/fzf
  /opt/homebrew/bin/helm
  /opt/homebrew/bin/kubectl
  /opt/homebrew/bin/terraform
  /opt/homebrew/bin/aws
  /opt/homebrew/bin/python3
)

# Include every installed node version (path contains the version, which changes)
local node_bin
for node_bin in "$HOME"/.nvm/versions/node/*/bin/node(N); do
  binaries+=("$node_bin")
done

# Fire them all in parallel. `--version` is a cheap invocation that triggers
# the validation path without doing real work. Output discarded.
local b
for b in "${binaries[@]}"; do
  [[ -x "$b" ]] && "$b" --version >/dev/null 2>&1 &
done
wait
