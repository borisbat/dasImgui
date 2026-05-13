options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``recording.apng`` against an
//! **already-running** daslang-live. This driver is also the tutorial
//! topic — the RST walks through every line below.
//!
//! Workflow (two shells):
//!
//!     # window 1 — host with cwd = the asset dir so the APNG lands there:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/tutorial/recording.das
//!
//!     # window 2 — fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_recording.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "recording.apng"

def widget_bbox(var snap : JsonValue?; ident : string) : float4 {
    //! Pull (x_min, y_min, x_max, y_max) out of the snapshot for one
    //! widget. The `?[...]` chain returns null on a missing path; the
    //! `?? 0.0f` coalesces missing axes to zero so callers don't have
    //! to null-check each component.
    var b = snap?["globals"]?[ident]?["bbox"]
    return float4(
        b?["x"] ?? 0.0f,
        b?["y"] ?? 0.0f,
        b?["z"] ?? 0.0f,
        b?["w"] ?? 0.0f
    )
}

def widget_center(var snap : JsonValue?; ident : string) : tuple<float; float> {
    //! Cursor-target helper — the driver moves the synth cursor to the
    //! center of the widget's bbox so the trail visibly travels to it.
    let b = widget_bbox(snap, ident)
    return ((b.x + b.z) * 0.5f, (b.y + b.w) * 0.5f)
}

[export]
def main {
    // ---- 1. Connect to the live host ----
    // ImguiApp bundles the HTTP transport + base URL into a value the
    // playwright helpers (post_command, move_to, click_at, ...) all
    // take as their first arg.
    let app = ImguiApp(
        base_url = BASE_URL,
        feature_path = "",
        transport <- live_api_transport(BASE_URL)
    )
    print("[record] connecting to {BASE_URL}\n")
    if (!wait_until_ready(app, 5.0f)) {
        panic("daslang-live not responding on {BASE_URL} — is it running with recording.das?")
    }

    // ---- 2. Resolve widget centers from a snapshot ----
    // wait_for_render polls imgui_snapshot until the named widget
    // appears (covers the cold-start gap where the subject is up but
    // first frame hasn't rendered). 10s timeout is generous.
    let T_VOLUME = "REC_WIN/VOLUME"
    let T_SAVE   = "REC_WIN/SAVE_BTN"
    var snap = wait_for_render(app, T_SAVE, 10.0f)
    if (snap == null) {
        panic("{T_SAVE} never rendered — wrong app running on {BASE_URL}?")
    }
    let p_volume = widget_center(snap, T_VOLUME)
    let p_save   = widget_center(snap, T_SAVE)

    // Volume drag: 15% to 80% along the slider's bbox width.
    let vol_bb = widget_bbox(snap, T_VOLUME)
    let vol_y  = (vol_bb.y + vol_bb.w) * 0.5f
    let vol_x0 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.15f
    let vol_x1 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.80f

    // ---- 3. Enable visual aids BEFORE record_start ----
    // mouse_trail draws the fading line behind the synth cursor;
    // cursor_sprite draws a visible pointer at io.MousePos so the
    // recording shows what's clicking what. Enable both first so the
    // very first frame of the APNG already has the cursor visible.
    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))

    // ---- 4. record_start: opens the APNG writer ----
    // file lands next to daslang-live's cwd (we set that to
    // doc/source/_static/tutorials/ in shell 1). max_seconds caps the
    // recording so a runaway driver doesn't churn disk forever.
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 30)))

    //! Pacing rule (LOCKED): `frames` is the app's frame counter (60 fps
    //! under vsync), NOT the recorder's fps. For ~3s readable narrate:
    //!     frames = 180   →  3.0s visible
    //!     sleep  = 3500u →  narrate disappears with ~500ms gap before next
    //! Then ~1500ms result dwell after the action.

    // ---- 5. Narrate then act — repeat ----

    // Stage 1: slider drag
    post_command(app, "imgui_narrate", JV((
        text = "imgui_narrate posts a sticky-note over a target.",
        target = T_VOLUME,
        frames = 200
    )))
    move_to(app, p_volume)
    sleep(3500u)
    var slider_events : array<JsonValue?>
    slider_events |> drag_along(0, (vol_x0, vol_y), (vol_x1, vol_y), 1400)
    post_command(app, "imgui_mouse_play", JV((events = slider_events)))
    sleep(2500u)

    // Stage 2: click the button
    post_command(app, "imgui_narrate", JV((
        text = "imgui_mouse_play feeds a scripted timeline of events.",
        target = T_SAVE,
        frames = 200
    )))
    move_to(app, p_save)
    sleep(3500u)
    var save_events : array<JsonValue?>
    save_events |> click_at(0, p_save)
    post_command(app, "imgui_mouse_play", JV((events = save_events)))
    sleep(1500u)

    // ---- 6. record_stop: flushes the APNG writer, prints stats ----
    // The response carries (frames, duration_s, dropped, saved) — a quick
    // sanity check for the driver author.
    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    // ---- 7. Disable visual aids ----
    // The host stays alive after the driver exits; clean up so the next
    // driver (or a developer poking at the live host manually) starts
    // from a clean state.
    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
