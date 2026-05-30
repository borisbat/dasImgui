options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``edit_external_tour.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_edit_external.das
//!
//! Walks the boost-v2 external-pointer rail:
//!   1. edit_slider_float -- drag along bbox
//!   2. edit_input_int -- focus + key_type
//!   3. edit_checkbox -- click
//!   4. edit_drag_float3 -- imgui_force_set vector
//!   5. edit_color_edit3 -- imgui_force_set float3
//!   6. edit_combo -- imgui_force_set int
//!   7. edit_slider_angle -- imgui_force_set radians

let RESULT_MS  = 2000u
let TAIL_MS    = 1500u

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
    with_recording_app("examples/tutorial/editing_external.das",
                       "edit_external_tour.apng", 75) $(app) {
        var snap = wait_for_render(app, "EDITOR_WIN/VOL_SLIDER", 10.0f)
        if (snap == null) {
            panic("EDITOR_WIN/VOL_SLIDER never rendered -- wrong app?")
        }

        let p_count   = widget_center(snap, "EDITOR_WIN/COUNT_INPUT")
        let p_enabled = widget_center(snap, "EDITOR_WIN/ENABLED_CHECK")
        let p_pos     = widget_center(snap, "EDITOR_WIN/POS_DRAG")
        let p_color   = widget_center(snap, "EDITOR_WIN/ACCENT_COLOR")
        let p_combo   = widget_center(snap, "EDITOR_WIN/QUALITY_COMBO")
        let p_angle   = widget_center(snap, "EDITOR_WIN/ANGLE_SLIDER")

        //! VOL_SLIDER: drag from 20% -> 75% along its bbox.
        let vol_bb = widget_bbox(snap, "EDITOR_WIN/VOL_SLIDER")
        let vol_y  = (vol_bb.y + vol_bb.w) * 0.5f
        let vol_x0 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.20f
        let vol_x1 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.75f

        //! Initial cursor placement (flips synth_cursor_owned).
        move_to(app, (400.0f, 360.0f), 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: edit_slider_float drag ----
        move_to(app, (vol_x0, vol_y), 900)
        sleep(SETTLE_MS)
        say(app, "edit_slider_float -- drag updates the external float through safe_addr.", "EDITOR_WIN/VOL_SLIDER")
        var slider_events : array<JsonValue?>
        slider_events |> drag_along(0, (vol_x0, vol_y), (vol_x1, vol_y), 1200, 400)
        post_command(app, "imgui_mouse_play", JV((events = slider_events)))
        sleep(uint(2200))
        sleep(RESULT_MS)

        // ---- Stage 2: edit_input_int focus + type ----
        move_to(app, p_count, 900)
        sleep(SETTLE_MS)
        say(app, "edit_input_int -- focus and type into the external int.", "EDITOR_WIN/COUNT_INPUT")
        post_command(app, "imgui_focus", JV((target = "EDITOR_WIN/COUNT_INPUT")))
        sleep(400u)
        post_command(app, "imgui_key_type", JV((text = "42", total_duration_s = 1.2f)))
        sleep(RESULT_MS)

        // ---- Stage 3: edit_checkbox click ----
        move_to(app, p_enabled, 900)
        sleep(SETTLE_MS)
        say(app, "edit_checkbox -- click toggles the external bool.", "EDITOR_WIN/ENABLED_CHECK")
        var check_events : array<JsonValue?>
        check_events |> click_at(0, p_enabled, 250)
        post_command(app, "imgui_mouse_play", JV((events = check_events)))
        sleep(RESULT_MS)

        // ---- Stage 4: edit_drag_float3 via imgui_force_set ----
        move_to(app, p_pos, 900)
        sleep(SETTLE_MS)
        say(app, "edit_drag_float3 -- vector write via imgui_force_set + unsafe(reinterpret).", "EDITOR_WIN/POS_DRAG")
        post_command(app, "imgui_force_set", JV((target = "EDITOR_WIN/POS_DRAG",
                                           value = float3(1.5f, 2.5f, 3.5f))))
        sleep(RESULT_MS)

        // ---- Stage 5: edit_color_edit3 via imgui_force_set ----
        move_to(app, p_color, 900)
        sleep(SETTLE_MS)
        say(app, "edit_color_edit3 -- float3 round-trips into the swatch.", "EDITOR_WIN/ACCENT_COLOR")
        post_command(app, "imgui_force_set", JV((target = "EDITOR_WIN/ACCENT_COLOR",
                                           value = float3(0.35f, 0.70f, 0.90f))))
        sleep(RESULT_MS)

        // ---- Stage 6: edit_combo via imgui_force_set ----
        move_to(app, p_combo, 900)
        sleep(SETTLE_MS)
        say(app, "edit_combo -- pick a preset by index (popup item bboxes need a click first).", "EDITOR_WIN/QUALITY_COMBO")
        post_command(app, "imgui_force_set", JV((target = "EDITOR_WIN/QUALITY_COMBO", value = 2)))
        sleep(RESULT_MS)

        // ---- Stage 7: edit_slider_angle via imgui_force_set ----
        move_to(app, p_angle, 900)
        sleep(SETTLE_MS)
        say(app, "edit_slider_angle -- radians under the hood; UI shows degrees.", "EDITOR_WIN/ANGLE_SLIDER")
        post_command(app, "imgui_force_set", JV((target = "EDITOR_WIN/ANGLE_SLIDER", value = 1.0f)))
        sleep(RESULT_MS)
        sleep(TAIL_MS)
    }
}
