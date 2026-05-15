# Changelog

## Unreleased

### Added

- `imgui/imgui_harness` — canonical wrapper module for examples/tests. Hides
  GLFW/OpenGL backend boilerplate behind five helpers (`harness_init`,
  `harness_begin_frame`, `harness_new_frame`, `harness_end_frame`,
  `harness_shutdown`) plus optional `harness_apply_synth_io`. Re-exports the
  backend-agnostic dasImgui v2 stack so example files need only a single
  `require imgui/imgui_harness` line. The `--headless` CLI flag is parsed
  but panics with a clear "land PR 2 first" message — full headless dispatch
  + the `imgui_app_headless` C++ backend land in a follow-up PR.

### Changed

- `examples/features/foundation.das` ported to `imgui/imgui_harness` as the
  canary adopter. 15 requires collapse to one; the GLFW/GL update boilerplate
  collapses to two helper calls bracketing the user widget block.
