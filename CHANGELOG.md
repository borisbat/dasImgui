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
- `imgui/imgui_harness_lint` — default-on `[lint_macro]` that fires on any
  file requiring `imgui/imgui_harness` and forbids direct calls into the
  windowed-backend modules (`glfw_boost`, `opengl_boost`, `glfw_live`,
  `opengl_live`, `imgui_live`). Diagnostic code `HARNESS001`
  (macro_error 50503). Bundled transitively via
  `require imgui/imgui_harness_lint public` from `imgui_harness.das`.
  Per-file opt-out: `options _allow_glfw_calls = true` (scaffolding only,
  target end-state = no opt-out — same shape as PR #33's
  `_allow_imgui_legacy`).
- `tests/integration/failed_imgui_harness_lint_raw.das` — negative fixture
  proving the default-on lint fires. Uses `expect 50503` so dastest treats
  the compile failure as a PASS.
- CI: `tests.yml` resurrected. Now runs on every push/PR (was parked
  `workflow_dispatch:` since the xvfb/Mesa hang). The integration suite
  drives daslang-live in headless mode — `imgui_playwright` reads
  `--headless` from its own `get_user_args()` and appends `-- --headless`
  to every spawned subprocess. No `xvfb-run`, no virtual display.
  Depends on daslang PR #2681 (daslang-live forwards post-`--` argv to
  scripts via `setCommandLineArguments`). Local smoke: 98/111 PASS
  headless; the 13 failures (and CI excludes) are
  `test_glfw_synth_keys`, `test_glfw_synth_mouse`,
  `test_visual_aids_key_hud` — all post `key_press` / `mouse_*` HTTP
  commands targeting `glfw_live`'s synth driver, which has no event
  queue without a GLFW context. Inherently windowed-only; revisit
  alongside a windowed CI job or a backend-neutral key-event API.
- CI: `docs.yml` no longer filters by `paths:` — any change to
  `master` rebuilds and republishes. The narrow `doc/**` + `widgets/**`
  filter silently skipped PRs that only touched `examples/**` or
  `CHANGELOG.md`, leaving the site stale vs master.

### Changed

- `examples/features/foundation.das` and `active_widget.das` ported to
  `imgui/imgui_harness` (PR 1+2; restated here for completeness).
- First migration batch (this PR) — 12 additional `examples/features/`
  files ported to the harness API. Each file dropped 14 requires + ~25
  lines of GLFW/GL boilerplate down to a single
  `require imgui/imgui_harness` + 5 helper calls. All verified working in
  both windowed (live mode) and headless (`--headless --headless-frames=60`)
  modes; integration suite: 111/111 PASS (was 110/110 before lint canary):
    - `narrative_text.das`, `narrative_bullet.das`, `narrative_separator.das`
    - `output_text.das`
    - `with_indent.das`, `with_item_width.das`, `with_text_wrap_pos.das`
    - `menu_main.das`, `menu_label_static.das`
    - `tooltip_flat.das`
    - `button_repeat.das`, `collapsing_header_closable.das`
    - `disabled_block.das`
- `imgui_harness.das` re-exports broadened to include all sibling
  `imgui_*_builtin` modules (`imgui_scope_builtin`, `imgui_id_builtin`,
  `imgui_style_builtin`, `imgui_layout_builtin`, `imgui_docking_builtin`,
  `imgui_colors`). Matches the design intent — one require should bring
  the full backend-agnostic dasImgui v2 surface into scope. Migration
  batch surfaced the gap (5 of 13 files needed a second require for
  `scope_builtin` before the harness was extended).
- **Second migration batch (this PR) — all 48 remaining `examples/features/`
  files ported to the harness API.** With the 15 already-migrated files
  (foundation, active_widget, and the 13 from PR 3), every file under
  `examples/features/` now uses `require imgui/imgui_harness`. Net
  diff: +345 / -1680 across 48 files (mechanical 14-require chain →
  single require, 25-line update/shutdown boilerplate → 5 helper calls).
  Three sub-patterns covered:
    - **Canonical (35 files)** — `await_quiescent`, `clip_rect`,
      `containers_layout/_overlay/_window`, `display_image/_progress`,
      `drag_drop`, `focus_widget`, `font_stack`, `hex_id_click`,
      `id_override`, `indexed_dynamic`, `inputs_choice/_color/_drag/`
      `_indexed/_numeric/_slider/_text`, `io_mirror`, `io_synth_drag/_text`,
      `layout_primitives`, `list_box`, `plot_getter/_widgets`,
      `popup_context_item`, `scroll_state`, `snapshot_unrendered`,
      `style_override`, `transport_demo`, `triggers`, `widget_init_defaults`,
      `widget_no_ident`.
    - **Synth-IO (7 files)** — `columns_demo`, `dock_basic`, `layout_helpers`,
      `glfw_synth_keys/_mouse`, `imgui_synth_keys/_mouse`. These call
      `harness_apply_synth_io()` between `harness_begin_frame()` and
      `harness_new_frame()` (the slot where `apply_synth_io_override()`
      used to live).
    - **edit_external (6 files)** — `edit_external_color/_combo/_scalars/`
      `_special/_toggles/_vectors`. Preserve the `require daslib/safe_addr`
      that the family uses for caller-owned pointer args.
  Verified per-file: `compile_check` + `lint` + `format_file` clean,
  headless smoke (60 frames) exit 0, windowed smoke (5 s timeout-killed)
  ran. Full dastest integration: 111/111 PASS (unchanged).
