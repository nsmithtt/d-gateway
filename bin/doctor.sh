#!/usr/bin/env bash
# Prints the version of everything the workbench is supposed to provide. The
# fastest way to confirm a rebuild actually picked up a version bump.
set -uo pipefail

check() {
  local name="$1"; shift
  if command -v "$1" >/dev/null 2>&1; then
    printf '  %-8s %s\n' "$name" "$("$@" 2>&1 | head -1)"
  else
    printf '  %-8s MISSING\n' "$name"
    return 1
  fi
}

rc=0
echo "gateway workbench toolchain:"
check python python --version || rc=1
check uv     uv --version      || rc=1
check git    git --version     || rc=1
check tmux   tmux -V           || rc=1
check nvim   nvim --version    || rc=1
check herdr  herdr --version   || rc=1
check rg     rg --version      || rc=1
check fd     fd --version      || rc=1
exit "$rc"
