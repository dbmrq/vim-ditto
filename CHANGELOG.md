# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and
this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.4.0] - 2026-11-21

### Added

- Self-contained unit and integration tests for Vim and Neovim.
- End-to-end test that drives a real Neovim TUI in tmux, verifies rendered
  highlight attributes, and captures screenshots.
- GitHub Actions CI for tests plus an E2E job that uploads the screenshots.
- Release checklist and version metadata checks.
- Full Vim license text.

### Changed

- Sentence and paragraph highlighting now computes line ranges directly
  instead of using `:global`, visual selections, or cursor movement.
- Mode state is stored in one buffer-local variable instead of three flags.
- Good words are resolved lazily and matched case-insensitively as exact words.
- `:DittoOff` and `:NoDitto` now remove their autocmds.
- Documentation now includes requirements, plugin-manager installation, and
  development instructions.

### Fixed

- `<Plug>DittoOff` called a function that did not exist.
- `:DittoOn` ignored `g:ditto_mode = "file"`.
- Good words were matched as substrings or regexes instead of exact words.
- `:DittoGood` and `:DittoBad` errored on buffers after the first one.
- Repeated commands added duplicate matches, and overlapping updates left stale
  matches behind.
- Repeated `:DittoOn` calls added duplicate autocmds.
- Sentence mode raised `E20: Mark not set`.
- Neovim 0.12 flickering caused by cursor/visual-mode churn during updates
  (issue #10).
