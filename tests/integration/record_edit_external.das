options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options _no_imgui_legacy = true

require imgui public
require imgui/imgui_lint
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``edit_external_tour.apng`` against an
//! **already-running** daslang-live hosting
//! ``examples/tutorial/editing_external.das``.
//!
//! Walks the boost-v2 external-pointer rail (commits 10a/10b/10c):
//!   1. edit_slider_float — drag along bbox
//!   2. edit_input_int — focus + key_type
//!   3. edit_checkbox — click
//!   4. edit_drag_float3 — imgui_set (vector round-trip)
//!   5. edit_color_edit3 — imgui_set float3
//!   6. edit_combo — imgui_set int
//!   7. edit_slider_angle — imgui_set radians
//!
//! Workflow (two shells):
//!
//!     # window 1 — host with cwd = the asset dir:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/tutorial/editing_external.das
//!
//!     # window 2 — fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_edit_external.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "edit_external_tour.apng"

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
        panic("daslang-live not responding on {BASE_URL} — is it running with editing_external.das?")
    }

    var snap = wait_for_render(app, "EDITOR_WIN/VOL_SLIDER", 10.0f)
    if (snap == null) {
        panic("EDITOR_WIN/VOL_SLIDER never rendered — wrong app on {BASE_URL}?")
    }

    let p_count   = widget_center(snap, "EDITOR_WIN/COUNT_INPUT")
    let p_enabled = widget_center(snap, "EDITOR_WIN/ENABLED_CHECK")

    // VOL_SLIDER: drag from 20% → 75% along its bbox.
    let vol_bb = widget_bbox(snap, "EDITOR_WIN/VOL_SLIDER")
    let vol_y  = (vol_bb.y + vol_bb.w) * 0.5f
    let vol_x0 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.20f
    let vol_x1 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.75f

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 120)))

    //! Locked pacing: frames=180 / sleep=3500u/1500u / 60fps app-side.

    // ---- Stage 1: edit_slider_float drag ----
    post_command(app, "imgui_narrate", JV((
        text = "edit_slider_float — drag updates the external float through safe_addr.",
        target = "EDITOR_WIN/VOL_SLIDER",
        frames = 180
    )))
    sleep(3500u)
    var slider_events : array<JsonValue?>
    slider_events |> drag_along(0, (vol_x0, vol_y), (vol_x1, vol_y), 1400)
    post_command(app, "imgui_mouse_play", JV((events = slider_events)))
    sleep(2500u)

    // ---- Stage 2: edit_input_int focus + type ----
    post_command(app, "imgui_narrate", JV((
        text = "edit_input_int — focus and type into the external int.",
        target = "EDITOR_WIN/COUNT_INPUT",
        frames = 180
    )))
    move_to(app, p_count)
    sleep(3500u)
    post_command(app, "imgui_focus", JV((target = "EDITOR_WIN/COUNT_INPUT")))
    sleep(400u)
    post_command(app, "imgui_key_type", JV((text = "42", total_duration_s = 1.2f)))
    sleep(2500u)

    // ---- Stage 3: edit_checkbox click ----
    post_command(app, "imgui_narrate", JV((
        text = "edit_checkbox — click toggles the external bool.",
        target = "EDITOR_WIN/ENABLED_CHECK",
        frames = 180
    )))
    sleep(3500u)
    var check_events : array<JsonValue?>
    check_events |> click_at(0, p_enabled)
    post_command(app, "imgui_mouse_play", JV((events = check_events)))
    sleep(1800u)

    // ---- Stage 4: edit_drag_float3 via imgui_set ----
    post_command(app, "imgui_narrate", JV((
        text = "edit_drag_float3 — vector write through unsafe(reinterpret).",
        target = "EDITOR_WIN/POS_DRAG",
        frames = 180
    )))
    sleep(3500u)
    post_command(app, "imgui_set", JV((target = "EDITOR_WIN/POS_DRAG", value = float3(1.5f, 2.5f, 3.5f))))
    sleep(2000u)

    // ---- Stage 5: edit_color_edit3 via imgui_set ----
    post_command(app, "imgui_narrate", JV((
        text = "edit_color_edit3 — float3 round-trips into the swatch.",
        target = "EDITOR_WIN/ACCENT_COLOR",
        frames = 180
    )))
    sleep(3500u)
    post_command(app, "imgui_set", JV((target = "EDITOR_WIN/ACCENT_COLOR", value = float3(0.35f, 0.70f, 0.90f))))
    sleep(2000u)

    // ---- Stage 6: edit_combo via imgui_set ----
    // Popup item bboxes only render after click — for tutorial recordings the
    // imgui_set path is sufficient narration.
    post_command(app, "imgui_narrate", JV((
        text = "edit_combo — pick a preset by index.",
        target = "EDITOR_WIN/QUALITY_COMBO",
        frames = 180
    )))
    sleep(3500u)
    post_command(app, "imgui_set", JV((target = "EDITOR_WIN/QUALITY_COMBO", value = 2)))
    sleep(2000u)

    // ---- Stage 7: edit_slider_angle via imgui_set ----
    post_command(app, "imgui_narrate", JV((
        text = "edit_slider_angle — radians under the hood.",
        target = "EDITOR_WIN/ANGLE_SLIDER",
        frames = 180
    )))
    sleep(3500u)
    post_command(app, "imgui_set", JV((target = "EDITOR_WIN/ANGLE_SLIDER", value = 1.0f)))
    sleep(2000u)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
