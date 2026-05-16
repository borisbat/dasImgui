# Changelog

## Unreleased

### Added

- `imgui/imgui_harness` — canonical wrapper module for examples/tests. Hides
  GLFW/OpenGL backend boilerplate behind five helpers (`harness_init`,
  `harness_begin_frame`, `harness_new_frame`, `harness_end_frame`,
  `harness_shutdown`) plus optional `harness_apply_synth_io`. Re-exports the
  backend-agnostic dasImgui v2 stack so example files need only a single
  `require imgui/imgui_harness` line.
- `imgui_app_headless.shared_module` — display-less C++ backend (3-fn
  surface: `imgui_headless_init_fonts`, `imgui_headless_set_display_size`,
  `imgui_headless_advance_dt`). No GLFW, no OpenGL, no gl3w. Used by
  `imgui_harness` when its `--headless` arm is active; the GLFW/GL symbol
  set is structurally absent from headless scope.
- `--headless` CLI flag in `imgui_harness` — pass after the daslang `--`
  separator (`daslang FILE.das -- --headless`) to run with no window and no
  GL context. CPU-only font atlas, real wall-clock `DeltaTime`, `Render()`
  output discarded. Synth IO (`imgui_mouse_play`, `imgui_key_chord`, …)
  works in both modes via the existing `imgui_*` `[live_command]` family.
- `--headless-frames=N` CLI flag — auto-exit after `N` frames. Useful for
  unattended CI smokes that have no out-of-band exit signal.
- New tutorial: `doc/source/tutorials/harness_headless_mode.rst` — walks
  through what `--headless` dispatches to, how to launch in either mode,
  and the limits (`screenshot` / `record_*` and live-API HTTP stay
  windowed-only).

### Changed

- `examples/features/foundation.das` ported to `imgui/imgui_harness` as the
  first canary adopter. 15 requires collapse to one; the GLFW/GL update
  boilerplate collapses to two helper calls bracketing the user widget block.
- `examples/features/active_widget.das` ported to `imgui/imgui_harness` as
  the second canary — exercises the boost runtime + Playwright-style
  command surface (`imgui_click`, `imgui_snapshot`) under both modes.
