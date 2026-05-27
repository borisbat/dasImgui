options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``popups.apng`` against
//! ``examples/tutorial/popups.das``. Drives two right-click context
//! popups — popup_context_item (anchored to a button) and
//! popup_context_window (anchored to the enclosing window) — via the
//! new ``right_click(app, target)`` helper. The popups are
//! ``stateless_finalize`` (no pending_open/pending_close); ImGui drives
//! open/close internally from real ``IsItemClicked(1)`` checks, which
//! is why the synth has to be a real mouse event with button=1 (the
//! ``right_click`` helper routes ``imgui_click`` through the L1
//! ``click_at_coro`` path when button != 0).

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
                       "popups.apng", 50) $(app) {
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

        // ---- Stage 1: right-click PO_TARGET to open popup_context_item ----
        move_to(app, p_target, 600)
        sleep(SETTLE_MS)
        right_click(app, T_TARGET)
        sleep(CLICK_DWELL_MS)
        say(app, "right_click on PO_TARGET — popup_context_item opens, anchored to the PREVIOUSLY submitted item. stateless_finalize: ImGui owns open/close; body runs only while visible.", T_TARGET)

        // ---- Stage 2: dismiss + right-click PO_HINT for popup_context_window ----
        // Left-click anywhere outside the popup dismisses it.
        move_to(app, p_hint, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_click", JV((target = T_HINT)))
        sleep(CLICK_DWELL_MS)

        right_click(app, T_HINT)
        sleep(CLICK_DWELL_MS)
        say(app, "right_click on PO_HINT — popup_context_window opens, anchored to the ENCLOSING window. Same flags, same stateless model.", T_HINT)
    }
}
