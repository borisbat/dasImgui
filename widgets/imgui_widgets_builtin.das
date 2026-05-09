options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module imgui_widgets_builtin shared

require imgui public
require imgui/imgui_boost_runtime public
require imgui/imgui_boost_v2 public

//! Built-in widgets defined via `[widget]` — the same mechanism users get.
//! `define_widget` is the canonical extension path; these are the first two
//! examples. New widgets land here (or in user modules) without touching the
//! macro layer.

[widget]
def button(var state : ButtonState; text : string) : bool {
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
    return changed
}
