options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``with_id.apng`` against an **already-running**
//! daslang-live.
//!
//! Workflow (two shells):
//!
//!     # window 1 — host with cwd = the asset dir so the APNG lands there:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/tutorial/with_id.das
//!
//!     # window 2 — fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_with_id.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "with_id.apng"

def widget_bbox(var snap : JsonValue?; ident : string) : float4 {
    var b = snap?["globals"]?[ident]?["bbox"]
    return float4(
        b?["x"] ?? 0.0f,
        b?["y"] ?? 0.0f,
        b?["z"] ?? 0.0f,
        b?["w"] ?? 0.0f
    )
}

def widget_center(var snap : JsonValue?; ident : string) : tuple<float; float> {
    let b = widget_bbox(snap, ident)
    return ((b.x + b.z) * 0.5f, (b.y + b.w) * 0.5f)
}

[export]
def main {
    let app = ImguiApp(
        base_url = BASE_URL,
        feature_path = "",
        transport <- live_api_transport(BASE_URL)
    )
    print("[record] connecting to {BASE_URL}\n")
    if (!wait_until_ready(app, 5.0f)) {
        panic("daslang-live not responding on {BASE_URL} — is it running with with_id.das?")
    }

    //! Targets are path-qualified — the `window(ID_WIN, ...)` boost
    //! container pushes its name, and `with_id("…")` adds further segments.
    let T_SAVE_A      = "ID_WIN/section_a/SAVE_BTN"
    let T_SAVE_B      = "ID_WIN/section_b/SAVE_BTN"
    let T_NESTED      = "ID_WIN/outer/inner/NESTED_BTN"
    let T_HASHED      = "ID_WIN/HASHED_BTN"
    let T_RPS_PATH    = "ID_WIN/rps_stable"

    var snap = wait_for_render(app, T_SAVE_A, 10.0f)
    if (snap == null) {
        panic("{T_SAVE_A} never rendered — wrong app running on {BASE_URL}?")
    }
    let p_save_a  = widget_center(snap, T_SAVE_A)
    let p_save_b  = widget_center(snap, T_SAVE_B)
    let p_nested  = widget_center(snap, T_NESTED)
    let p_hashed  = widget_center(snap, T_HASHED)
    let p_rps     = widget_center(snap, T_RPS_PATH)

    //! Slider drag (path= demo): drag from 15% to 75% along the slider bbox.
    let rps_bb = widget_bbox(snap, T_RPS_PATH)
    let rps_y  = (rps_bb.y + rps_bb.w) * 0.5f
    let rps_x0 = rps_bb.x + (rps_bb.z - rps_bb.x) * 0.15f
    let rps_x1 = rps_bb.x + (rps_bb.z - rps_bb.x) * 0.75f

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 60)))

    //! Pacing rule (LOCKED): `frames` is the app's frame counter (60 fps
    //! under vsync), NOT the recorder's fps. For ~3s readable narrate:
    //!     frames = 180   →  3.0s visible
    //!     sleep  = 3500u →  narrate disappears with ~500ms gap before next
    //! Then ~1500ms result dwell after the action.

    // ---- Stage 1: two scopes, same widget identifier ----
    post_command(app, "imgui_narrate", JV((
        text = "with_id scopes a render — same SAVE_BTN, two paths.",
        target = T_SAVE_A,
        frames = 180
    )))
    move_to(app, p_save_a)
    sleep(3500u)
    var save_a_events : array<JsonValue?>
    save_a_events |> click_at(0, p_save_a)
    post_command(app, "imgui_mouse_play", JV((events = save_a_events)))
    sleep(1500u)

    post_command(app, "imgui_narrate", JV((
        text = "section_b path → distinct ImGui hash + own click count slot.",
        target = T_SAVE_B,
        frames = 180
    )))
    move_to(app, p_save_b)
    sleep(3500u)
    var save_b_events : array<JsonValue?>
    save_b_events |> click_at(0, p_save_b)
    post_command(app, "imgui_mouse_play", JV((events = save_b_events)))
    sleep(1500u)

    // ---- Stage 2: nested with_id chain ----
    post_command(app, "imgui_narrate", JV((
        text = "Nested with_id — segments join with /.",
        target = T_NESTED,
        frames = 200
    )))
    move_to(app, p_nested)
    sleep(3500u)
    var nested_events : array<JsonValue?>
    nested_events |> click_at(0, p_nested)
    post_command(app, "imgui_mouse_play", JV((events = nested_events)))
    sleep(1500u)

    // ---- Stage 3: id= per-call sugar ----
    post_command(app, "imgui_narrate", JV((
        text = "id= mangles the ImGui hash; telemetry path unchanged.",
        target = T_HASHED,
        frames = 200
    )))
    move_to(app, p_hashed)
    sleep(3500u)
    var hashed_events : array<JsonValue?>
    hashed_events |> click_at(0, p_hashed)
    post_command(app, "imgui_mouse_play", JV((events = hashed_events)))
    sleep(1500u)

    // ---- Stage 4: path= per-call sugar ----
    post_command(app, "imgui_narrate", JV((
        text = "path= replaces the registry path leaf.",
        target = T_RPS_PATH,
        frames = 200
    )))
    move_to(app, p_rps)
    sleep(3500u)
    var rps_events : array<JsonValue?>
    rps_events |> drag_along(0, (rps_x0, rps_y), (rps_x1, rps_y), 1400)
    post_command(app, "imgui_mouse_play", JV((events = rps_events)))
    sleep(2000u)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
