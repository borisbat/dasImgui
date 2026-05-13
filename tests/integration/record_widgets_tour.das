options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``widgets_tour.apng`` against an **already-running**
//! daslang-live.
//!
//! Workflow (two shells):
//!
//!     # window 1 — host with cwd = the asset dir so the APNG lands there:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/tutorial/widgets_tour.das
//!
//!     # window 2 — fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_widgets_tour.das
//!
//! The driver enables mouse trail + cursor sprite, posts a narrate post-it
//! before each widget, performs a representative interaction, then calls
//! record_stop to flush the writer cleanly.

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "widgets_tour.apng"

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
        panic("daslang-live not responding on {BASE_URL} — is it running with widgets_tour.das?")
    }

    var snap = wait_for_render(app, "SAVE_BTN", 10.0f)
    if (snap == null) {
        panic("SAVE_BTN never rendered — wrong app running on {BASE_URL}?")
    }
    let p_user_name = widget_center(snap, "USER_NAME")
    let p_muted     = widget_center(snap, "MUTED")
    let p_save      = widget_center(snap, "SAVE_BTN")

    // VOLUME slider: drag from 15% to 80% along its bbox.
    let vol_bb = widget_bbox(snap, "VOLUME")
    let vol_y  = (vol_bb.y + vol_bb.w) * 0.5f
    let vol_x0 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.15f
    let vol_x1 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.80f

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 60)))

    // ---- Stage 1: text input ----
    // Narrate first so the post-it is up before we type. Focus via API
    // (cleaner than synth-click for tour purposes) then run a paced type.
    post_command(app, "imgui_narrate", JV((
        text = "Type your name into the field.",
        target = "USER_NAME",
        frames = 180
    )))
    move_to(app, p_user_name)
    sleep(1100u)
    post_command(app, "imgui_focus", JV((target = "USER_NAME")))
    sleep(400u)
    post_command(app, "imgui_key_type", JV((text = "Alice", total_duration_s = 2.5f)))
    sleep(3200u)

    // ---- Stage 2: slider drag ----
    post_command(app, "imgui_narrate", JV((
        text = "Drag the slider to set the volume.",
        target = "VOLUME",
        frames = 180
    )))
    sleep(600u)
    var slider_events : array<JsonValue?>
    slider_events |> drag_along(0, (vol_x0, vol_y), (vol_x1, vol_y), 1400)
    post_command(app, "imgui_mouse_play", JV((events = slider_events)))
    sleep(2400u)

    // ---- Stage 3: checkbox click ----
    post_command(app, "imgui_narrate", JV((
        text = "Click to mute.",
        target = "MUTED",
        frames = 150
    )))
    sleep(500u)
    var muted_events : array<JsonValue?>
    muted_events |> click_at(0, p_muted)
    post_command(app, "imgui_mouse_play", JV((events = muted_events)))
    sleep(1400u)

    // ---- Stage 4: combo via imgui_set ----
    // Opening a combo + clicking a popup item requires the popup to render
    // before its bboxes appear in the snapshot. For a tutorial recording the
    // simpler path is to imgui_set the value while the narrate post-it
    // explains what just happened.
    post_command(app, "imgui_narrate", JV((
        text = "Pick a quality preset.",
        target = "QUALITY",
        frames = 180
    )))
    sleep(900u)
    post_command(app, "imgui_set", JV((target = "QUALITY", value = 2)))
    sleep(1400u)

    // ---- Stage 5: color editor via imgui_set ----
    post_command(app, "imgui_narrate", JV((
        text = "Tune the accent color.",
        target = "TINT",
        frames = 180
    )))
    sleep(900u)
    post_command(app, "imgui_set", JV((target = "TINT", value = float3(0.25f, 0.75f, 0.45f))))
    sleep(1400u)

    // ---- Stage 6: button click ----
    post_command(app, "imgui_narrate", JV((
        text = "Save the settings.",
        target = "SAVE_BTN",
        frames = 180
    )))
    sleep(600u)
    var save_events : array<JsonValue?>
    save_events |> click_at(0, p_save)
    post_command(app, "imgui_mouse_play", JV((events = save_events)))
    sleep(1800u)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
