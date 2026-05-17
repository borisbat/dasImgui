options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``recording.apng`` — also the tutorial topic,
//! the RST walks every line below. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_recording.das
//!
//! :ref:`with_recording_app <function-imgui_playwright_with_recording_app>`
//! spawns daslang-live on the tutorial, passes ``--imgui-content-scale=1.0``
//! and ``--no-hdpi-framebuffer`` so capture stays at logical 1x even on
//! retina, toggles visual aids around the body, posts ``record_start`` /
//! ``record_stop``, drives shutdown. APNG lands at
//! ``<dasImgui>/doc/source/_static/tutorials/recording.apng``.

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
    with_recording_app("examples/tutorial/recording.das",
                       "recording.apng", 30) $(app) {
        // ---- Resolve widget centers from a snapshot ----
        // wait_for_render polls imgui_snapshot until the named widget
        // appears (covers the cold-start gap where the subject is up but
        // the first frame hasn't rendered). 10s timeout is generous.
        let T_VOLUME = "REC_WIN/VOLUME"
        let T_SAVE   = "REC_WIN/SAVE_BTN"
        var snap = wait_for_render(app, T_SAVE, 10.0f)
        if (snap == null) {
            panic("{T_SAVE} never rendered — wrong app running?")
        }
        let p_volume = widget_center(snap, T_VOLUME)
        let p_save   = widget_center(snap, T_SAVE)

        // Volume drag: 15% to 80% along the slider's bbox width.
        let vol_bb = widget_bbox(snap, T_VOLUME)
        let vol_y  = (vol_bb.y + vol_bb.w) * 0.5f
        let vol_x0 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.15f
        let vol_x1 = vol_bb.x + (vol_bb.z - vol_bb.x) * 0.80f

        //! Pacing rule (LOCKED): `frames` is the app's frame counter (60 fps
        //! under vsync), NOT the recorder's fps. For ~3s readable narrate:
        //!     frames = 180   →  3.0s visible
        //!     sleep  = 3500u →  narrate disappears with ~500ms gap before next
        //! Then ~1500ms result dwell after the action.

        // ---- Narrate then act — repeat ----

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
    }
}
