options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``drag_drop.apng`` against an **already-running**
//! daslang-live. Mirrors record_widgets_tour.das / record_layout.das.
//!
//! Workflow (two shells):
//!
//!     # window 1 — host with cwd = the asset dir so the APNG lands there:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/features/drag_drop.das
//!
//!     # window 2 — fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_drag_drop.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "drag_drop.apng"

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
        panic("daslang-live not responding on {BASE_URL} — is it running with drag_drop.das?")
    }

    let T_SOURCE = "MAIN_WIN/SOURCE_BTN"
    let T_TARGET = "MAIN_WIN/TARGET_BTN"

    var snap = wait_for_render(app, T_SOURCE, 10.0f)
    if (snap == null) {
        panic("{T_SOURCE} never rendered — wrong app running on {BASE_URL}?")
    }
    let p_source = widget_center(snap, T_SOURCE)
    let p_target = widget_center(snap, T_TARGET)

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 30)))

    // Stage 1 — intro narration on the SOURCE button.
    post_command(app, "imgui_narrate", JV((
        text = "drag_drop_source attaches to the previous item.",
        target = T_SOURCE,
        frames = 200
    )))
    move_to(app, p_source)
    sleep(3500u)

    // Stage 2 — narration on the TARGET button.
    post_command(app, "imgui_narrate", JV((
        text = "drag_drop_target accepts a typed payload.",
        target = T_TARGET,
        frames = 200
    )))
    move_to(app, p_target)
    sleep(3500u)

    // Stage 3 — perform the drag. drag_to handles the synth press → moves → release.
    post_command(app, "imgui_narrate", JV((
        text = "drag_to(source, target) bridges bboxes automatically.",
        target = T_SOURCE,
        frames = 200
    )))
    sleep(2500u)
    drag_to(app, T_SOURCE, T_TARGET, 10, 0)
    sleep(2500u)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
