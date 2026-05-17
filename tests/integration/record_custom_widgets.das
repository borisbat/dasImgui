options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``custom_widgets.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_custom_widgets.das

def widget_bbox(var snap : JsonValue?; ident : string) : float4 {
    //! Pull (x_min, y_min, x_max, y_max) out of the snapshot for one widget.
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
    with_recording_app("examples/tutorial/custom_widgets.das",
                       "custom_widgets.apng", 24) $(app) {
        // ---- Resolve widget centers from a snapshot ----
        let T_MASTER = "MIXER_WIN/MASTER"
        let T_TREBLE = "MIXER_WIN/TREBLE"
        let T_BASS   = "MIXER_WIN/BASS"
        let T_RESET  = "MIXER_WIN/RESET_BTN"
        var snap = wait_for_render(app, T_RESET, 10.0f)
        if (snap == null) {
            panic("{T_RESET} never rendered — wrong app running?")
        }
        let p_master = widget_center(snap, T_MASTER)
        let p_treble = widget_center(snap, T_TREBLE)
        let p_bass   = widget_center(snap, T_BASS)
        let p_reset  = widget_center(snap, T_RESET)

        // The knob is angular: atan2(mouse - center) drives value directly.
        // Drag endpoints must stay in the active 270° arc (i.e. NOT in the
        // 90° dead zone at the bottom). Straight lines through center are the
        // hazard — pick endpoints with the same sign of dy (both above center).
        //
        // MASTER (bounds 0..1, starts at 0): drag from "7 o'clock" position
        // (matches starting value, no press-jump) up and over to "12 o'clock".
        // Value sweeps 0 → 0.5.
        let r = 22.0f
        let drag_start_master = (p_master._0 - r * 0.707f, p_master._1 + r * 0.707f)
        let drag_end_master   = (p_master._0,              p_master._1 - r)

        // TREBLE (bounds -1..1, starts at 0): drag from "12" to "2 o'clock".
        // Value sweeps 0 → 0.33 — visible without crossing dead zone.
        let drag_start_treble = (p_treble._0,              p_treble._1 - r)
        let drag_end_treble   = (p_treble._0 + r * 0.707f, p_treble._1 - r * 0.707f)

        // Pacing rule (LOCKED): `frames` is the app's frame counter (60 fps under
        // vsync), NOT the recorder's fps.
        //     frames = 180   →  3.0s visible narrate
        //     sleep  = 3500u →  narrate disappears with ~500ms gap before next
        //     sleep  = 1500u →  result dwell after action

        // ---- Narrate then act — one beat per knob ----

        // Beat 1: drag MASTER from 7 o'clock to 12 — value rises 0 → 0.5
        post_command(app, "imgui_narrate", JV((
            text = "ImGui ships no rotary widget. We add one with [widget].",
            target = T_MASTER,
            frames = 200
        )))
        move_to(app, p_master)
        sleep(3500u)
        var ev_master : array<JsonValue?>
        ev_master |> drag_along(0, drag_start_master, drag_end_master, 1200)
        post_command(app, "imgui_mouse_play", JV((events = ev_master)))
        sleep(2000u)

        // Beat 2: drag TREBLE from 12 to 2 o'clock — value rises 0 → ~0.33
        post_command(app, "imgui_narrate", JV((
            text = "State struct matches slider_float — pending_value_finalize Just Works.",
            target = T_TREBLE,
            frames = 200
        )))
        move_to(app, p_treble)
        sleep(3500u)
        var ev_treble : array<JsonValue?>
        ev_treble |> drag_along(0, drag_start_treble, drag_end_treble, 1200)
        post_command(app, "imgui_mouse_play", JV((events = ev_treble)))
        sleep(2000u)

        // Beat 3: imgui_set BASS — show that the live API path works on custom widgets too
        post_command(app, "imgui_narrate", JV((
            text = "imgui_set drives custom widgets the same way — no extra wiring.",
            target = T_BASS,
            frames = 200
        )))
        move_to(app, p_bass)
        sleep(3500u)
        post_command(app, "imgui_set", JV((target = T_BASS, value = -0.5f)))
        sleep(2000u)

        // Beat 4: click RESET_BTN — ordinary built-in on the same panel
        post_command(app, "imgui_narrate", JV((
            text = "RESET_BTN is an ordinary built-in button — same registry.",
            target = T_RESET,
            frames = 200
        )))
        move_to(app, p_reset)
        sleep(3500u)
        var ev_reset : array<JsonValue?>
        ev_reset |> click_at(0, p_reset)
        post_command(app, "imgui_mouse_play", JV((events = ev_reset)))
        sleep(1500u)
    }
}
