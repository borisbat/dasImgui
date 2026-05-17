options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``with_style.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_with_style.das

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
    with_recording_app("examples/tutorial/with_style.das",
                       "with_style.apng", 60) $(app) {
        //! Targets are path-qualified — the `window(STYLE_WIN, ...)` boost
        //! container pushes its name onto the registry path.
        let T_STYLED        = "STYLE_WIN/STYLED_BTN"
        let T_NESTED_STYLED = "STYLE_WIN/NESTED_STYLED_BTN"
        let T_UNSTYLED      = "STYLE_WIN/UNSTYLED_BTN"

        var snap = wait_for_render(app, T_STYLED, 10.0f)
        if (snap == null) {
            panic("{T_STYLED} never rendered — wrong app running?")
        }
        let p_styled        = widget_center(snap, T_STYLED)
        let p_nested_styled = widget_center(snap, T_NESTED_STYLED)
        let p_unstyled      = widget_center(snap, T_UNSTYLED)

        //! Pacing rule (LOCKED): `frames` is the app's frame counter (60 fps
        //! under vsync), NOT the recorder's fps. For ~3s readable narrate:
        //!     frames = 180   →  3.0s visible
        //!     sleep  = 3500u →  narrate disappears with ~500ms gap before next
        //! Then ~1500ms for the actual interaction (click / drag / dwell).

        // ---- Stage 1: mixed color + var in one block ----
        post_command(app, "imgui_narrate", JV((
            text = "with_style pushes color + style-var as one block.",
            target = T_STYLED,
            frames = 180
        )))
        move_to(app, p_styled)
        sleep(3500u)
        var styled_events : array<JsonValue?>
        styled_events |> click_at(0, p_styled)
        post_command(app, "imgui_mouse_play", JV((events = styled_events)))
        sleep(1500u)

        // ---- Stage 2: nested with_style — inner stacks on outer ----
        post_command(app, "imgui_narrate", JV((
            text = "Nested with_style — inner additions stack on outer.",
            target = T_NESTED_STYLED,
            frames = 180
        )))
        move_to(app, p_nested_styled)
        sleep(3500u)
        var nested_events : array<JsonValue?>
        nested_events |> click_at(0, p_nested_styled)
        post_command(app, "imgui_mouse_play", JV((events = nested_events)))
        sleep(1500u)

        // ---- Stage 3: pop balance — baseline restored ----
        post_command(app, "imgui_narrate", JV((
            text = "After the block — baseline style is restored.",
            target = T_UNSTYLED,
            frames = 180
        )))
        move_to(app, p_unstyled)
        sleep(3500u)
        var unstyled_events : array<JsonValue?>
        unstyled_events |> click_at(0, p_unstyled)
        post_command(app, "imgui_mouse_play", JV((events = unstyled_events)))
        sleep(1700u)
    }
}
