options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module imgui_widgets_builtin shared

require imgui public
require imgui/imgui_boost_runtime public
require imgui/imgui_boost_v2 public
require daslib/json public
require daslib/json_boost

//! Built-in widgets defined via `[widget]` — the same mechanism users get.
//! Each def constructs two short closures (serializer + dispatcher) and
//! hands them to widget_finalize. Common per-frame fields (hex_id/bbox/
//! hover/active/focus) are captured inside widget_finalize; per-kind state
//! lives in the state struct alone.

[widget]
def button(var state : ClickState; text : string) : bool {
    let im_clicked = Button(text, ImVec2(0.0f, 0.0f))
    var clicked = im_clicked
    if (state.pending_click) {
        state.pending_click = false
        clicked = true
    }
    state.clicked = clicked
    if (clicked) {
        state.click_count++
    }
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue? {
            return JV(state)
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue?) {
            if (action == "click") {
                state.pending_click = true
            }
        }
        widget_finalize(widget_ident, "button", entry, ser, disp)
    }
    return clicked
}

[widget]
def slider(var state : SliderStateFloat; text : string) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = SliderFloat(text, unsafe(addr(state.value)), mn, mx, "%.3f", ImGuiSliderFlags.None)
    state.changed = changed
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue? {
            return JV(state)
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue?) {
            if (action == "set") {
                state.pending_value = from_JV(payload?["value"], type<float>, 0.0f)
                state.has_pending = true
            }
        }
        widget_finalize(widget_ident, "slider", entry, ser, disp)
    }
    return changed
}

[widget]
def slider_int(var state : SliderStateInt; text : string) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = SliderInt(text, unsafe(addr(state.value)), mn, mx, "%d", ImGuiSliderFlags.None)
    state.changed = changed
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue? {
            return JV(state)
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue?) {
            if (action == "set") {
                state.pending_value = from_JV(payload?["value"], type<int>, 0)
                state.has_pending = true
            }
        }
        widget_finalize(widget_ident, "slider_int", entry, ser, disp)
    }
    return changed
}
