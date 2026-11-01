#!/usr/bin/env bash
# Removes build folders older than the given number of days (default 7).
set -eu
days=${1:-7}
find ./builds -mindepth 1 -maxdepth 1 -type d -mtime +"$days" -print0 |
  while IFS= read -r -d '' dir; do
    rm -rf "$dir"
    echo "removed $dir"
  done
