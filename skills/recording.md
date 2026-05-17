# Recording APNG demos

dasImgui ships its tutorial site at `doc/source/` with an APNG per tutorial page (`doc/source/_static/tutorials/*.apng`). Recordings are produced by **two-shell driver scripts** under `tests/integration/record_*.das` that talk to a running `daslang-live` host via its HTTP live-API (port 9090). Recordings are NOT in CI — they're manually-driven artifact producers, committed as binary APNGs alongside the driver script.

This page is the recipe. Read before writing or revising any `record_*.das` driver.

## Mental model

A recording has three independent layers:

1. **Host**: `daslang-live.exe` running a feature file (`examples/tutorial/X.das` or `examples/imgui_demo/harness_X.das`). The host opens a window, runs your `update()` loop at 60 fps, listens for live-commands on port 9090.
2. **Driver**: `daslang.exe tests/integration/record_X.das` runs once, posts live-commands to the host, waits for them to play out, exits. Sequence: `record_start` → `imgui_narrate` → `imgui_mouse_play` → sleep → `record_stop`.
3. **Visual overlays**: `imgui_cursor_sprite` (red+white circle at synth pos) + `imgui_mouse_trail` (fading dotted line behind cursor). Both paint to the **foreground draw list** during the host's `end_of_frame()`. Enabled via live-commands before `record_start`.

The recorder captures the host's framebuffer at `fps` Hz starting on `record_start` and saves an APNG when `record_stop` fires.

## Pre-requisites for the host

If the host is a **tutorial** (`examples/tutorial/*.das`, `live_*` lifecycle): nothing extra — these files already call `apply_synth_io_override()` between `ImGui_ImplGlfw_NewFrame()` and `NewFrame()`.

If the host is a **harness** (`examples/features/*.das` or `examples/imgui_demo/harness_*.das`, `harness_*` lifecycle): the harness **must call `harness_apply_synth_io()`** between `harness_begin_frame()` and `harness_new_frame()`. Without it:

- `synth_cursor_owned` stays `false` (GLFW's mouse poll wins the per-frame race);
- `imgui_cursor_sprite` paints at the real OS cursor (off-window) → invisible in recording;
- `imgui_mouse_trail` same;
- synth clicks never reach ImGui's hover/active state → menus stay closed, buttons don't activate.

The harness API exposes `harness_apply_synth_io()` as OPTIONAL because most feature smokes only `wait_for_widget` without driving input. Once you record one, it becomes mandatory.

## Two-shell workflow

`<daslang>` = path to a daslang build tree, `<dasimgui>` = path to this repo. Append `.exe` on Windows.

Shell 1 (host) — cwd = the asset directory so the APNG lands next to its siblings:

```bash
cd <dasimgui>/doc/source/_static/tutorials
<daslang>/bin/Release/daslang-live -project_root <dasimgui> \
    <dasimgui>/examples/imgui_demo/harness_about.das
```

Wait for `live_api: server started on port 9090` to print.

Shell 2 (driver):

```bash
<daslang>/bin/Release/daslang -project_root <dasimgui> \
    <dasimgui>/tests/integration/record_imgui_demo_about.das
```

Driver exits when `record_stop` returns. The APNG lands in shell 1's cwd (`doc/source/_static/tutorials/`).

**Always full-restart the host between recording iterations.** Any interactive probe (menu click, key press) you ran via `mcp__daslang__live_command` leaves state — open menus, scrolled positions, toggled widgets — that contaminates the next recording. Stop `daslang-live` / `imguiApp` processes; relaunch fresh.

## Driver template

Mirror `tests/integration/record_with_id.das` (canonical) or `record_imgui_demo_about.das` (harness-targeting). Spine:

```daslang
options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "scene_name.apng"

let NARRATE_FRAMES = 240      //! 4.0s visible at 60 fps app
let READ_MS    = 5000u        //! 5s read + 1s gap before next action
let SETTLE_MS  = 1500u        //! 1.5s cursor settle before next narrate
let RESULT_MS  = 2000u        //! 2s action result dwell

def widget_bbox(var snap : JsonValue?; ident : string) : float4 { ... }
def widget_center(var snap : JsonValue?; ident : string) : tuple<float; float> { ... }

[export]
def main {
    let app = ImguiApp(
        base_url = BASE_URL,
        feature_path = "",
        transport <- live_api_transport(BASE_URL)
    )
    if (!wait_until_ready(app, 5.0f)) {
        panic("daslang-live not responding on {BASE_URL}")
    }
    var snap = wait_for_render(app, "ROOT_IDENT", 10.0f)
    if (snap == null) { panic("ROOT_IDENT never rendered") }

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start",
                 JV((file = OUTPUT, fps = 30, max_seconds = 45)))

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

    post_command(app, "record_stop", null)
    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
```

## Reader pacing (LOCKED)

Recordings are for **readers**, not test assertions. Every stage gets explicit time:

| Constant | Value | Phase |
|---|---|---|
| `NARRATE_FRAMES` | `240` | 4.0s narrate visibility (`frames` is the app's per-frame counter at 60 fps, NOT the recorder's fps) |
| `READ_MS` | `5000u` | After posting narrate: 5s read window + ~1s gap before next action |
| `SETTLE_MS` | `1500u` | After `move_to`: 1.5s for cursor to settle visually before next narrate |
| `RESULT_MS` | `2000u` | After `click_at`/`imgui_mouse_play` of an interaction: 2s dwell so the reader sees the result |

A recording that fits in 30s is usually too dense. Bump `record_start max_seconds` to 45-60 for multi-stage flows.

Don't use the old `record_with_id.das` pacing (`frames = 180`, `sleep(3500u)`) for new recordings — Boris's feedback: it's too fast for readers. The `record_with_id.das` template predates the pacing audit; treat its constants as legacy, not canonical.

## `imgui_playwright` helpers

The `widgets/imgui_playwright.das` module exposes:

- `move_to(app, pos, duration_ms = 600)` — lerps cursor from last tracked position to `pos`; updates the tracked pos for the next call.
- `click_at(var events, t_ms, pos, travel_ms = 500, button = 0)` — appends lerp + press + release + dwell to an events array. Call `post_command(app, "imgui_mouse_play", JV((events = events)))` to fire.
- `drag_along(var events, t_ms, from_pos, to_pos, drag_ms, approach_ms = 400)` — lerp-to-start + press + drag + release.

Each `imgui_mouse_play` call **resets the timeline** (`mouse_play_idx = 0`, `mouse_play_start = now`), so building events incrementally across stages means one `imgui_mouse_play` per stage, not one big timeline.

## Resolving widget coords

Most widgets work with `widget_center(snap, "PATH/TO/WIDGET")`. But for `main_menu_bar` and its `menu()` children, the registered bbox is **`(0, 0, 0, 0)`**:

```json
"MAIN_BAR_DEMO/APP_MENU_FILE" : {
    "kind": "menu", "hex_id": 3151082496,
    "bbox": { "x": 0, "y": 0, "z": 0, "w": 0 }
}
```

Cause: `stateless_finalize` reads `GetItemRectMin/Max` which is degenerate for menu-bar chrome at finalize time. `widget_center` therefore returns `(0, 0)` and clicks miss the top-left corner.

**Workaround**: hardcode the pixel coords. Find them empirically:

1. Launch the host normally, see the menu in the window.
2. Use `mcp__daslang__live_command name="screenshot" args='{"file":"/tmp/probe.png"}'` to capture the framebuffer.
3. Read the PNG; measure menu-header pixel positions visually.
4. Bake them as constants in the driver:

```daslang
let P_FILE_HEADER = (24.0f,  10.0f)   //! "File" label
let P_EDIT_HEADER = (56.0f,  10.0f)   //! "Edit" after "File "
let P_FILE_COLORS = (50.0f, 173.0f)   //! Colors row inside File menu
```

Submenu items DO register bboxes correctly **once the parent is open**. If you need them dynamically, click parent first, then `wait_for_render` + `widget_center` for the child.

(Followup: fix `widgets/imgui_containers_builtin.das`'s menu containers to capture bbox at `BeginMenu` return time, before `EndMenu`. Then `widget_center` works uniformly. Not in scope for any current PR.)

## Verifying a recording without playing it

Don't rely on eyeballs alone — instrument it. Two probes:

### Probe 1: live-process screenshot (state at *this moment*)

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

`doc/source/_static/tutorials/`. Each tutorial RST under `doc/source/tutorials/*.rst` cites its APNG via:

```rst
.. image:: ../_static/tutorials/scene_name.apng
   :alt: scene_name recording
```

CI's sphinx step uses `-W` (warnings-as-errors), so an RST referencing a missing APNG fails the build. Pair every new tutorial commit with the APNG commit ahead of it (APNG-first, then RST). The APNG-only intermediate state is fine — only the RST cite trips `-W`.

Existing APNG size range: 7.5 MB → 75 MB. Anything outside that is suspicious (too short = under-paced; too long = uncompressed/oversized).

## Commit structure for a new recording

For a new scene `foo`:

1. Commit 1: `recording: foo` — `tests/integration/record_foo.das` + `doc/source/_static/tutorials/foo.apng`.
2. PAUSE for eyeball review.
3. Commit 2: `tutorial: foo RST page` — `doc/source/tutorials/foo.rst` + `doc/source/tutorials/index.rst` toctree entry.

If recording multiple scenes in one PR, repeat 1+2 per scene with a PAUSE between scenes. Boris's project workflow: eyeball-only review, no Copilot, branches as backup.
