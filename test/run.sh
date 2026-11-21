#!/bin/sh
set -u

root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root" || exit 1

status=0
vim_bin=${VIM_BIN:-vim}
nvim_bin=${NVIM_BIN:-nvim}

if command -v "$vim_bin" >/dev/null 2>&1; then
  echo "Running tests with $("$vim_bin" --version | head -n 1)"
  "$vim_bin" -Nu NONE -n -es -S test/run.vim || status=1
else
  echo "Vim not found; skipping." >&2
fi

if command -v "$nvim_bin" >/dev/null 2>&1; then
  echo "Running tests with $("$nvim_bin" --version | head -n 1)"
  "$nvim_bin" --headless -u NONE -n -S test/run.vim 2>&1 || status=1
else
  echo "Neovim not found; skipping." >&2
fi

exit "$status"
