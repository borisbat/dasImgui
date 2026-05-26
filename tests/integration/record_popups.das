options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``popups.apng`` against
//! ``examples/tutorial/popups.das``. Narrates two right-click context
//! popups — popup_context_item and popup_context_window.
//!
//! popup_context_* is stateless_finalize (no pending_open / pending_close);
//! ImGui drives open/close internally on actual right-click events.
//! There's no imgui_right_click synth command, so the recording cannot
//! programmatically open the popups. Instead the driver narrates the
//! widget code + the static target — viewers read the prose for the
//! right-click interaction and try it themselves under daslang-live.

let NARRATE_FRAMES = 180        //! 6s visible at the app's 30 fps target
let READ_MS        = 3500u      //! 3.5s read window per stage
let SETTLE_MS      = 1200u      //! 1.2s cursor settle

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
    with_recording_app("examples/tutorial/popups.das",
                       "popups.apng", 30, 30) $(app) {
        let T_TARGET = "PO_WIN/PO_TARGET"
        let T_HINT   = "PO_WIN/PO_HINT"

        var snap = wait_for_widget(app, T_TARGET, 10.0f)
        if (snap == null) {
            panic("{T_TARGET} never registered — wrong app running?")
        }
        let p_target = widget_center(snap, T_TARGET)
        let p_hint   = widget_center(snap, T_HINT)

        //! Initial cursor placement.
        move_to(app, p_target, 500)
        sleep(SETTLE_MS)

        // ---- Stage 1: narrate popup_context_item ----
        post_command(app, "imgui_narrate", JV((
            text = "popup_context_item — attaches to the PREVIOUSLY submitted item. Right-click the button below to open its menu. stateless_finalize: ImGui owns open/close, body runs only while visible.",
            target = T_TARGET,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: narrate popup_context_window ----
        move_to(app, p_hint, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "popup_context_window — attaches to the ENCLOSING window. Right-click empty space anywhere inside the window to open. Same flags, same stateless model.",
            target = T_HINT,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
    }
}
