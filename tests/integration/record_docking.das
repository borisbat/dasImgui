options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``docking.apng`` against an **already-running**
//! daslang-live. Mirrors record_layout.das.
//!
//! Workflow (two shells):
//!
//!     # window 1 — host with cwd = the asset dir so the APNG lands there:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/tutorial/docking.das
//!
//!     # window 2 — fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_docking.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "docking.apng"

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
        panic("daslang-live not responding on {BASE_URL} — is it running with docking.das?")
    }

    //! Targets are path-qualified — dockspace pushes onto the registry path.
    let T_EXPLORER    = "DOCK_ROOT/EXPLORER"
    let T_SOURCE      = "DOCK_ROOT/SOURCE"
    let T_OUTPUT      = "DOCK_ROOT/OUTPUT"
    let T_REFRESH_BTN = "DOCK_ROOT/EXPLORER/REFRESH_BTN"
    let T_SAVE_BTN    = "DOCK_ROOT/SOURCE/SAVE_BTN"
    let T_CLEAR_BTN   = "DOCK_ROOT/OUTPUT/CLEAR_BTN"

    var snap = wait_for_render(app, T_REFRESH_BTN, 10.0f)
    if (snap == null) {
        panic("{T_REFRESH_BTN} never rendered — wrong app running on {BASE_URL}?")
    }
    let p_refresh = widget_center(snap, T_REFRESH_BTN)
    let p_save    = widget_center(snap, T_SAVE_BTN)
    let p_clear   = widget_center(snap, T_CLEAR_BTN)

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 60)))

    //! Pacing rule (LOCKED): `frames` is the app's frame counter (60 fps
    //! under vsync), NOT the recorder's fps. For ~3s readable narrate:
    //!     frames = 180   →  3.0s visible
    //!     sleep  = 3500u →  narrate disappears with ~500ms gap before next
    //! Then ~1500ms for the actual interaction (click / drag / dwell).

    // ---- Stage 1: tour the docked panels ----
    post_command(app, "imgui_narrate", JV((
        text = "ImGui native docking — three dockable panels.",
        target = T_EXPLORER,
        frames = 180
    )))
    move_to(app, p_refresh)
    sleep(3500u)

    post_command(app, "imgui_narrate", JV((
        text = "Each panel is a Begin/End window inside the dockspace.",
        target = T_SOURCE,
        frames = 180
    )))
    move_to(app, p_save)
    sleep(3500u)

    post_command(app, "imgui_narrate", JV((
        text = "Tabs are draggable — layout persists via imgui.ini.",
        target = T_OUTPUT,
        frames = 180
    )))
    move_to(app, p_clear)
    sleep(3500u)

    // ---- Stage 2: drive from outside — imgui_undock pops OUTPUT out ----
    // After undocking, ImGui places the floating window wherever imgui.ini
    // remembered (or (0,0) on first run). Pin it to a visible location with
    // imgui_set_window_pos so the demo clearly shows the panel detached.
    post_command(app, "imgui_narrate", JV((
        text = "imgui_undock + imgui_set_window_pos — panel floats free.",
        target = T_OUTPUT,
        frames = 200
    )))
    sleep(800u)
    post_command(app, "imgui_undock", JV((target = T_OUTPUT)))
    post_command(app, "imgui_set_window_pos", JV((
        target = T_OUTPUT,
        value = (x = 580.0f, y = 220.0f, w = 360.0f, h = 220.0f)
    )))
    sleep(3700u)

    // ---- Stage 3: reset the dockspace ----
    post_command(app, "imgui_narrate", JV((
        text = "imgui_dock_reset rebuilds the default layout.",
        target = T_EXPLORER,
        frames = 180
    )))
    sleep(800u)
    post_command(app, "imgui_dock_reset", JV((target = "DOCK_ROOT")))
    sleep(3000u)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
