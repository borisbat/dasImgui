options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``widgets_tour.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_widgets_tour.das
//!
//! Posts a narrate post-it before each widget, performs a representative
//! interaction, then exits.

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
    with_recording_app("examples/tutorial/widgets_tour.das",
                       "widgets_tour.apng", 90) $(app) {
        var snap = wait_for_render(app, "AUDIO_WIN/SAVE_BTN", 10.0f)
        if (snap == null) {
            panic("SAVE_BTN never rendered — wrong app running?")
        }
        let p_user_name = widget_center(snap, "AUDIO_WIN/USER_NAME")
        let p_muted     = widget_center(snap, "AUDIO_WIN/MUTED")
        let p_save      = widget_center(snap, "AUDIO_WIN/SAVE_BTN")

        // VOLUME slider: drag from 15% to 80% along its bbox.
        let vol_bb = widget_bbox(snap, "AUDIO_WIN/VOLUME")
        let vol_y  = (vol_bb.y + vol_bb.w) * 0.5f
        let vol_x0 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.15f
        let vol_x1 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.80f

        // ---- Stage 1: text input ----
        move_to(app, p_user_name)
        say(app, "Type your name into the field.", "AUDIO_WIN/USER_NAME")
        post_command(app, "imgui_focus", JV((target = "AUDIO_WIN/USER_NAME")))
        sleep(400u)
        post_command(app, "imgui_key_type", JV((text = "Alice", total_duration_s = 2.5f)))
        sleep(3000u)

        // ---- Stage 2: slider drag ----
        say(app, "Drag the slider to set the volume.", "AUDIO_WIN/VOLUME")
        var slider_events : array<JsonValue?>
        slider_events |> drag_along(0, (vol_x0, vol_y), (vol_x1, vol_y), 1400)
        post_command(app, "imgui_mouse_play", JV((events = slider_events)))
        sleep(2500u)

        // ---- Stage 3: checkbox click ----
        say(app, "Click to mute.", "AUDIO_WIN/MUTED")
        var muted_events : array<JsonValue?>
        muted_events |> click_at(0, p_muted)
        post_command(app, "imgui_mouse_play", JV((events = muted_events)))
        sleep(1500u)

        // ---- Stage 4: combo via imgui_force_set ----
        // Opening a combo + clicking a popup item requires the popup to render
        // before its bboxes appear in the snapshot. For a tutorial recording the
        // simpler path is to imgui_force_set the value while the narrate post-it
        // explains what just happened.
        say(app, "Pick a quality preset.", "AUDIO_WIN/QUALITY")
        post_command(app, "imgui_force_set", JV((target = "AUDIO_WIN/QUALITY", value = 2)))
        sleep(1500u)

        // ---- Stage 5: color editor via imgui_force_set ----
        say(app, "Tune the accent color.", "AUDIO_WIN/TINT")
        post_command(app, "imgui_force_set", JV((target = "AUDIO_WIN/TINT", value = float3(0.25f, 0.75f, 0.45f))))
        sleep(1500u)

        // ---- Stage 6: button click ----
        say(app, "Save the settings.", "AUDIO_WIN/SAVE_BTN")
        var save_events : array<JsonValue?>
        save_events |> click_at(0, p_save)
        post_command(app, "imgui_mouse_play", JV((events = save_events)))
        sleep(1800u)
    }
}
