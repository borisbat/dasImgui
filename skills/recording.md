# Recording APNG demos

dasImgui ships its tutorial site at `doc/source/` with an APNG per tutorial page (`doc/source/_static/tutorials/*.apng`). Recordings are produced by **one-shell driver scripts** under `tests/integration/record_*.das` that spawn their own `daslang-live` host via `with_recording_app` and post live-commands to it over HTTP. Recordings are NOT in CI — they're manually-driven artifact producers, committed as binary APNGs alongside the driver script.

This page is the recipe. Read before writing or revising any `record_*.das` driver.

## Mental model

A recording has three independent layers:

1. **Host**: `daslang-live.exe` running a feature file (`examples/tutorial/X.das` or `examples/features/X.das`). The host opens a window, runs your `update()` loop at 60 fps, listens for live-commands on port 9090. `with_recording_app` **spawns this host for you** with `--imgui-content-scale=1.0` + `--no-hdpi-framebuffer` so the framebuffer + ImGui style both stay at logical resolution (encoder-friendly APNGs even on retina). Tutorials run by users directly (no `--imgui-content-scale`) keep their native HDPI look.
2. **Driver**: `daslang.exe tests/integration/record_X.das` runs once. The `with_recording_app(feature, output, max_seconds) $(app) { ... }` helper spawns the host, waits ready, enables `imgui_cursor_sprite` + `imgui_mouse_trail`, posts `record_start`, invokes the body for the narrate/click/drag timeline, posts `record_stop`, disables the aids, and `/shutdown`s the host. Driver exits when the host process does.
3. **Visual overlays**: `imgui_cursor_sprite` (red+white circle at synth pos) + `imgui_mouse_trail` (fading dotted line behind cursor). Both paint to the **foreground draw list** during the host's `end_of_frame()`. The helper toggles them around the body; tour-specific overlays (`imgui_key_hud`, `imgui_focus_rect`) are body-managed (see `record_visual_aids.das`).

The recorder captures the host's framebuffer at `fps` Hz starting on `record_start` and saves an APNG when `record_stop` fires.

## Pre-requisites for the host

If the host is a **tutorial** (`examples/tutorial/*.das`, `live_*` lifecycle): nothing extra — these files already call `apply_synth_io_override()` between `ImGui_ImplGlfw_NewFrame()` and `NewFrame()`.

If the host is a **harness** (`examples/features/*.das`, `harness_*` lifecycle): the harness **must call `harness_apply_synth_io()`** between `harness_begin_frame()` and `harness_new_frame()`. Without it:

- `synth_cursor_owned` stays `false` (GLFW's mouse poll wins the per-frame race);
- `imgui_cursor_sprite` paints at the real OS cursor (off-window) → invisible in recording;
- `imgui_mouse_trail` same;
- synth clicks never reach ImGui's hover/active state → menus stay closed, buttons don't activate.

The harness API exposes `harness_apply_synth_io()` as OPTIONAL because most feature smokes only `wait_for_widget` without driving input. Once you record one, it becomes mandatory.

## One-shell workflow

`<daslang>` = path to a daslang build tree, `<dasimgui>` = path to this repo. Append `.exe` on Windows.

```bash
<daslang>/bin/Release/daslang -project_root <dasimgui> \
    <dasimgui>/tests/integration/record_with_id.das
```

The driver spawns daslang-live, runs the body, posts `/shutdown`, drains stdout. Total wall time = `max_seconds` + ~3s (boot + drain headroom). The APNG lands at `<dasimgui>/doc/source/_static/tutorials/<basename>.apng` — `with_recording_app` resolves the path via `get_this_module_dir()` so cwd doesn't matter.

**Concurrent driver runs collide on port 9090** (same risk as the playwright tests). Recording is interactive, one-at-a-time anyway; just don't fan them out.

## Driver template

Mirror `tests/integration/record_with_id.das` (canonical, `live_*` tutorial host) or `record_drag_drop.das` (harness-targeting). Spine:

```daslang
options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

let NARRATE_FRAMES = 240      //! 4.0s visible at 60 fps app
let READ_MS    = 5000u        //! 5s read + 1s gap before next action
let SETTLE_MS  = 1500u        //! 1.5s cursor settle before next narrate
let RESULT_MS  = 2000u        //! 2s action result dwell

def widget_bbox(var snap : JsonValue?; ident : string) : float4 { ... }
def widget_center(var snap : JsonValue?; ident : string) : tuple<float; float> { ... }

[export]
def main {
    with_recording_app("examples/tutorial/scene_name.das",
                       "scene_name.apng", 45) $(app) {
        var snap = wait_for_render(app, "ROOT_IDENT", 10.0f)
        if (snap == null) { panic("ROOT_IDENT never rendered") }

        //! Initial cursor placement -- flips synth_cursor_owned.
        move_to(app, (360.0f, 240.0f), 600)
        sleep(SETTLE_MS)

        // ---- Stage 1 ----
        move_to(app, p_target_1, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "...",
            target = "ROOT_IDENT",
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
        var events : array<JsonValue?>
        events |> click_at(0, p_target_1, 250)
        post_command(app, "imgui_mouse_play", JV((events = events)))
        sleep(RESULT_MS)
        // ... etc
    }
}
```

The 3-arg form uses fps=30 (the common case). For long recordings where file size matters more than smoothness, use the 4-arg overload with explicit fps:

```daslang
with_recording_app("examples/tutorial/narrative_layout_tour.das",
                   "narrative_layout_tour.apng", 75, 20) $(app) {
    // ... narrate/click/drag ...
}
```

Two drivers use fps=20: `record_boost_narrative_layout` (long progress-bar tour) and `record_edit_external` (slider drag + color picker pass that defeats APNG compression at 30 fps). Both stay under GitHub's 50 MB asset warning band.

## Tour-specific overlays

`with_recording_app` only toggles the `mouse_trail` + `cursor_sprite` pair that every recording uses. Drivers that need additional overlays (`imgui_key_hud`, `imgui_focus_rect`) enable/disable them **inside the body block**. See `record_visual_aids.das` — body posts `imgui_key_hud` / `imgui_focus_rect` enable at start, posts disable before returning.

## Reader pacing (LOCKED)

Recordings are for **readers**, not test assertions. Every stage gets explicit time:

| Constant | Value | Phase |
|---|---|---|
| `NARRATE_FRAMES` | `240` | 4.0s narrate visibility (`frames` is the app's per-frame counter at 60 fps, NOT the recorder's fps) |
| `READ_MS` | `5000u` | After posting narrate: 5s read window + ~1s gap before next action |
| `SETTLE_MS` | `1500u` | After `move_to`: 1.5s for cursor to settle visually before next narrate |
| `RESULT_MS` | `2000u` | After `click_at`/`imgui_mouse_play` of an interaction: 2s dwell so the reader sees the result |

A recording that fits in 30s is usually too dense. Bump the helper's `max_seconds` to 45-60 for multi-stage flows.

Don't use the old `record_with_id.das` pacing (`frames = 180`, `sleep(3500u)`) for new recordings — Boris's feedback: it's too fast for readers. The older drivers predate the pacing audit; treat those constants as legacy, not canonical.

## `imgui_playwright` helpers

The `widgets/imgui_playwright.das` module exposes:

- `with_recording_app(feature_path, output_basename, max_seconds, body)` — 3-arg form (fps=30 default). Spawns daslang-live for `<dasimgui>/<feature_path>`, posts record_start/stop bracket around `body`, shuts down. APNG lands at `<dasimgui>/doc/source/_static/tutorials/<output_basename>`.
- `with_recording_app(feature_path, output_basename, max_seconds, fps, body)` — 4-arg form for explicit fps (typically 20 for long captures).
- `with_imgui_app(feature_path, body)` / `with_imgui_app_opt(...)` — the playwright-test cousin (for `[test] def …(t : T?)` files). Forwards `--headless` from the parent. Recording uses the `_recording_` variant instead because it needs the GL framebuffer.
- `move_to(app, pos, duration_ms = 600)` — lerps cursor from last tracked position to `pos`; updates the tracked pos for the next call.
- `click_at(var events, t_ms, pos, travel_ms = 500, button = 0)` — appends lerp + press + release + dwell to an events array. Call `post_command(app, "imgui_mouse_play", JV((events = events)))` to fire.
- `drag_along(var events, t_ms, from_pos, to_pos, drag_ms, approach_ms = 400)` — lerp-to-start + press + drag + release.

Each `imgui_mouse_play` call **resets the timeline** (`mouse_play_idx = 0`, `mouse_play_start = now`), so building events incrementally across stages means one `imgui_mouse_play` per stage, not one big timeline.

## Resolving widget coords

Most widgets — including `menu()` children and `tab_item()` tab headers — work with `widget_center(snap, "PATH/TO/WIDGET")`. `widgets/imgui_containers_builtin.das` snapshots `GetItemRectMin/Max` immediately after `BeginMenu`/`BeginTabItem` returns, while the parent-strip header is still the "last item"; the registered bbox is the clickable header rect.

Two containers remain bbox-degenerate:

- **`main_menu_bar()`** itself — the viewport-attached bar chrome has no meaningful "header." `MAIN_BAR_DEMO` still reports `bbox = (0,0,0,0)`. The children (`menu()` paths under it) DO register correctly.
- **`window()` / `tab_bar()` containers** — these have a body, not a header. Their bbox is `(0,0,0,0)` and that's expected. Click targets are the contents, not the container shell.

If you need a `main_menu_bar` screen position (e.g. clicking outside any child menu to dismiss), hardcode pixel coords:

1. Launch the host normally, see the menu in the window.
2. Use `mcp__daslang__live_command name="screenshot" args='{"file":"/tmp/probe.png"}'` to capture the framebuffer.
3. Read the PNG; measure pixel positions visually.
4. Bake them as constants in the driver.

Submenu items DO register bboxes **once the parent is open** — click parent first via the parent's registered header bbox, then `wait_for_render` + `widget_center` for the child item.

For drivers that need to click outside any registered widget (`main_menu_bar` strip dismissal, raw-canvas coordinates, viewport-corner anchors), capture pixel coords empirically and bake them as named constants — see the "Resolving widget coords" recipe above.

## Verifying a recording without playing it

Don't rely on eyeballs alone — instrument it. Two probes:

### Probe 1: live-process screenshot (state at *this moment*)

Launch a host manually (not via the helper — you want it to stay alive after your probe), then drive it via MCP:

```
mcp__daslang__live_command name="imgui_mouse_play" args='{"events":[
    {"t_ms":0,"kind":"move","x":50,"y":15},
    {"t_ms":1000,"kind":"move","x":300,"y":300}]}'
mcp__daslang__live_command name="imgui_mouse_status"
mcp__daslang__live_command name="screenshot" args='{"file":"<dasimgui>/diag.png"}'
```

Then `Read` the PNG. Shows what daslang-live is rendering right now — cursor sprite, mouse trail, narrate callouts, foreground draw list, everything. If the screenshot shows what you expect but the APNG doesn't, the bug is in the recording path. If neither shows it, the synth IO isn't draining (recheck `harness_apply_synth_io`).

### Probe 2: extract individual frames from the APNG

```bash
ffmpeg -i scene.apng -vf "select=eq(n\,80)" -frames:v 1 -update 1 frame80.png -y
```

Notes:
- `-update 1` is REQUIRED for single-frame output (otherwise ffmpeg wants a `%d` pattern).
- `select=eq(n\,N)` picks frame N (0-based). Comma needs the backslash.

Pick 5-6 N values spanning the recording (e.g. 60 / 200 / 400 / 600 / 800 / 950 for a 1000-frame recording) and `Read` each PNG. This gives a fast story-arc check without watching the whole thing.

## Where APNGs land

`doc/source/_static/tutorials/`. The helper writes the absolute path via `dir_name(get_this_module_dir()) / RECORD_ASSET_REL` — same idiom `widgets/imgui_theme_daslang.das:155` uses for the bundled font. Caller cwd is irrelevant.

When dasImgui is daspkg-installed under `daScript/modules/dasImgui/`, the APNG lands in that install copy. For source-repo workflows (preferred for committing), launch the driver with `-project_root <dasimgui-source>` so the loaded copy IS the source repo, and the APNG lands where you can `git add` it directly. The helper forwards `-project_root` from the driver's own argv to the spawned daslang-live.

Each tutorial RST under `doc/source/tutorials/*.rst` cites its APNG via:

```rst
.. image:: ../_static/tutorials/scene_name.apng
   :alt: scene_name recording
```

CI's sphinx step uses `-W` (warnings-as-errors), so an RST referencing a missing APNG fails the build. Pair every new tutorial commit with the APNG commit ahead of it (APNG-first, then RST). The APNG-only intermediate state is fine — only the RST cite trips `-W`.

Existing APNG size range: 7.5 MB → 30 MB at logical 1x. Anything outside that is suspicious (too short = under-paced; too long = uncompressed/oversized).

## Commit structure for a new recording

For a new scene `foo`:

1. Commit 1: `recording: foo` — `tests/integration/record_foo.das` + `doc/source/_static/tutorials/foo.apng`.
2. PAUSE for eyeball review.
3. Commit 2: `tutorial: foo RST page` — `doc/source/tutorials/foo.rst` + `doc/source/tutorials/index.rst` toctree entry.

If recording multiple scenes in one PR, repeat 1+2 per scene with a PAUSE between scenes. Boris's project workflow: eyeball-only review, no Copilot, branches as backup.
