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
//!
//! Four private *_finalize helpers below collapse the repetitive
//! lambda-construction + widget_finalize call shared across click /
//! toggle / radio_int / pending-value widget families. Each widget def
//! stays focused on the imgui call + per-frame state mutation. The
//! `pending_value_finalize` helper is generic on the state struct and
//! drives `from_JV` off `typedecl(state.pending_value)` — one body
//! covers every Drag* / Slider* / Input* family without per-type
//! duplication.

// ===== Common finalize helpers =====

def private click_finalize(widget_ident : string; kind : string; var state : ClickState) {
    //! Lambda + dispatcher install for click-style widgets (Button family).
    //! Dispatcher action: "click" → state.pending_click = true (consumed next frame).
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue ? {
            return JV(state)
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue ?) {
            if (action == "click") {
                state.pending_click = true
            }
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
}

def private toggle_finalize(widget_ident : string; kind : string; var state : ToggleState) {
    //! Lambda + dispatcher install for bool-toggle widgets (Checkbox, RadioButton-bool,
    //! Selectable, MenuItem). Dispatcher action: "set" with bool payload.
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue ? {
            return JV(state)
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue ?) {
            if (action == "set") {
                state.pending_value = from_JV(payload?["value"], type<bool>, false)
                state.pending_toggle = true
            }
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
}

def private radio_int_finalize(widget_ident : string; kind : string; var state : RadioIntState) {
    //! Lambda + dispatcher install for the int-form RadioButton.
    //! Dispatcher action: "set" with int payload; renderer applies before the imgui call.
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue ? {
            return JV(state)
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue ?) {
            if (action == "set") {
                state.pending_value = from_JV(payload?["value"], type<int>, 0)
                state.pending_set = true
            }
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
}

def private pending_value_finalize(widget_ident : string; kind : string; var state : auto) {
    //! Lambda + dispatcher install for the pending-value family — every
    //! state shape with `has_pending` / `pending_value` / `changed`
    //! fields, dispatched on action "set". Generic on the state struct;
    //! `typedecl(state.pending_value)` drives the from_JV decode so one
    //! body covers all of Drag* (10 kinds) / Slider* (incl. VSlider, 10
    //! kinds) / Input numeric / Color / Combo / ListBox / InputText
    //! without per-type duplication.
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue ? {
            return JV(state)
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue ?) {
            if (action == "set") {
                state.pending_value = from_JV(payload?["value"],
                                              type<typedecl(state.pending_value)>,
                                              default<typedecl(state.pending_value)>)
                state.has_pending = true
            }
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
}

// ===== Triggers (click family) =====

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
    click_finalize(widget_ident, "button", state)
    return clicked
}

[widget]
def small_button(var state : ClickState; text : string) : bool {
    let im_clicked = SmallButton(text)
    var clicked = im_clicked
    if (state.pending_click) {
        state.pending_click = false
        clicked = true
    }
    state.clicked = clicked
    if (clicked) {
        state.click_count++
    }
    click_finalize(widget_ident, "small_button", state)
    return clicked
}

[widget]
def arrow_button(var state : ClickState; text : string; dir : ImGuiDir) : bool {
    let im_clicked = ArrowButton(text, dir)
    var clicked = im_clicked
    if (state.pending_click) {
        state.pending_click = false
        clicked = true
    }
    state.clicked = clicked
    if (clicked) {
        state.click_count++
    }
    click_finalize(widget_ident, "arrow_button", state)
    return clicked
}

[widget]
def invisible_button(var state : ClickState; text : string; size : float2;
                     flags : ImGuiButtonFlags = ImGuiButtonFlags.None) : bool {
    let im_clicked = InvisibleButton(text, size, flags)
    var clicked = im_clicked
    if (state.pending_click) {
        state.pending_click = false
        clicked = true
    }
    state.clicked = clicked
    if (clicked) {
        state.click_count++
    }
    click_finalize(widget_ident, "invisible_button", state)
    return clicked
}

[widget]
def image_button(var state : ClickState; text : string; user_texture_id : void?; size : float2;
                 uv0 : float2 = float2(0.0f, 0.0f);
                 uv1 : float2 = float2(1.0f, 1.0f);
                 bg_col : float4 = float4(0.0f, 0.0f, 0.0f, 0.0f);
                 tint_col : float4 = float4(1.0f, 1.0f, 1.0f, 1.0f)) : bool {
    let im_clicked = ImageButton(text, user_texture_id, size, uv0, uv1, bg_col, tint_col)
    var clicked = im_clicked
    if (state.pending_click) {
        state.pending_click = false
        clicked = true
    }
    state.clicked = clicked
    if (clicked) {
        state.click_count++
    }
    click_finalize(widget_ident, "image_button", state)
    return clicked
}

// ===== Toggles (bool family) =====

[widget]
def checkbox(var state : ToggleState; text : string) : bool {
    if (state.pending_toggle) {
        state.value = state.pending_value
        state.pending_toggle = false
    }
    let changed = Checkbox(text, unsafe(addr(state.value)))
    state.changed = changed
    toggle_finalize(widget_ident, "checkbox", state)
    return changed
}

[widget]
def radio_button(var state : ToggleState; text : string) : bool {
    //! Bool-form RadioButton — single toggle. ImGui's RadioButton(label,bool)
    //! does NOT mutate the bool, only returns true on click; daslang side
    //! flips state.value on click to give "single radio = checkbox shaped
    //! like a radio" semantics. Grouped radios use radio_button_int.
    if (state.pending_toggle) {
        state.value = state.pending_value
        state.pending_toggle = false
    }
    let im_clicked = RadioButton(text, state.value)
    if (im_clicked) {
        state.value = !state.value
    }
    state.changed = im_clicked
    toggle_finalize(widget_ident, "radio_button", state)
    return im_clicked
}

[widget]
def selectable(var state : ToggleState; text : string;
               flags : ImGuiSelectableFlags = ImGuiSelectableFlags.None;
               size : float2 = float2(0.0f, 0.0f)) : bool {
    if (state.pending_toggle) {
        state.value = state.pending_value
        state.pending_toggle = false
    }
    let changed = Selectable(text, unsafe(addr(state.value)), flags, size)
    state.changed = changed
    toggle_finalize(widget_ident, "selectable", state)
    return changed
}

[widget]
def menu_item(var state : ToggleState; text : string; shortcut : string = "") : bool {
    //! Non-block MenuItem with toggle semantics. The block-arg form (menu
    //! container) lands in 0b.3. `enabled = true` always; the disabled
    //! variant is a future per-call knob if real users hit it.
    if (state.pending_toggle) {
        state.value = state.pending_value
        state.pending_toggle = false
    }
    let changed = MenuItem(text, shortcut, unsafe(addr(state.value)), true)
    state.changed = changed
    toggle_finalize(widget_ident, "menu_item", state)
    return changed
}

// ===== Radio (int family) =====

[widget]
def radio_button_int(var state : RadioIntState; text : string; v_button : int) : bool {
    //! Grouped-radio form. Each call site picks `v_button`; click writes
    //! state.value = v_button. Multiple radio_button_int calls sharing the
    //! same RadioIntState ident form one logical group.
    if (state.pending_set) {
        state.value = state.pending_value
        state.pending_set = false
    }
    let changed = RadioButton(text, unsafe(addr(state.value)), v_button)
    state.changed = changed
    radio_int_finalize(widget_ident, "radio_button_int", state)
    return changed
}

// ===== Stateful inputs (drag family) =====

[widget]
def drag_float(var state : DragStateFloat; text : string;
               speed : float = 1.0f;
               format : string = "%.3f";
               flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = DragFloat(text, unsafe(addr(state.value)), speed, mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "drag_float", state)
    return changed
}

[widget]
def drag_float2(var state : DragStateFloat2; text : string;
                speed : float = 1.0f;
                format : string = "%.3f";
                flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = DragFloat2(text, unsafe(addr(state.value.x)), speed, mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "drag_float2", state)
    return changed
}

[widget]
def drag_float3(var state : DragStateFloat3; text : string;
                speed : float = 1.0f;
                format : string = "%.3f";
                flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = DragFloat3(text, unsafe(addr(state.value.x)), speed, mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "drag_float3", state)
    return changed
}

[widget]
def drag_float4(var state : DragStateFloat4; text : string;
                speed : float = 1.0f;
                format : string = "%.3f";
                flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = DragFloat4(text, unsafe(addr(state.value.x)), speed, mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "drag_float4", state)
    return changed
}

[widget]
def drag_int(var state : DragStateInt; text : string;
             speed : float = 1.0f;
             format : string = "%d";
             flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = DragInt(text, unsafe(addr(state.value)), speed, mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "drag_int", state)
    return changed
}

[widget]
def drag_int2(var state : DragStateInt2; text : string;
              speed : float = 1.0f;
              format : string = "%d";
              flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = DragInt2(text, unsafe(addr(state.value.x)), speed, mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "drag_int2", state)
    return changed
}

[widget]
def drag_int3(var state : DragStateInt3; text : string;
              speed : float = 1.0f;
              format : string = "%d";
              flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = DragInt3(text, unsafe(addr(state.value.x)), speed, mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "drag_int3", state)
    return changed
}

[widget]
def drag_int4(var state : DragStateInt4; text : string;
              speed : float = 1.0f;
              format : string = "%d";
              flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = DragInt4(text, unsafe(addr(state.value.x)), speed, mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "drag_int4", state)
    return changed
}

[widget]
def drag_float_range2(var state : DragStateRangeFloat; text : string;
                      speed : float = 1.0f;
                      format : string = "%.3f";
                      flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! Two-handle drag. `state.value.x` = current_min, `.y` = current_max;
    //! `state.bounds` clamps both. ImGui internally enforces lo <= hi each frame.
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = DragFloatRange2(text, unsafe(addr(state.value.x)), unsafe(addr(state.value.y)),
                                  speed, mn, mx, format, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "drag_float_range2", state)
    return changed
}

[widget]
def drag_int_range2(var state : DragStateRangeInt; text : string;
                    speed : float = 1.0f;
                    format : string = "%d";
                    flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = DragIntRange2(text, unsafe(addr(state.value.x)), unsafe(addr(state.value.y)),
                                speed, mn, mx, format, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "drag_int_range2", state)
    return changed
}

// ===== Stateful inputs (slider family) =====

[widget]
def slider_float(var state : SliderStateFloat; text : string;
                 format : string = "%.3f";
                 flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = SliderFloat(text, unsafe(addr(state.value)), mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "slider_float", state)
    return changed
}

[widget]
def slider_float2(var state : SliderStateFloat2; text : string;
                  format : string = "%.3f";
                  flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = SliderFloat2(text, unsafe(addr(state.value.x)), mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "slider_float2", state)
    return changed
}

[widget]
def slider_float3(var state : SliderStateFloat3; text : string;
                  format : string = "%.3f";
                  flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = SliderFloat3(text, unsafe(addr(state.value.x)), mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "slider_float3", state)
    return changed
}

[widget]
def slider_float4(var state : SliderStateFloat4; text : string;
                  format : string = "%.3f";
                  flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = SliderFloat4(text, unsafe(addr(state.value.x)), mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "slider_float4", state)
    return changed
}

[widget]
def slider_int(var state : SliderStateInt; text : string;
               format : string = "%d";
               flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = SliderInt(text, unsafe(addr(state.value)), mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "slider_int", state)
    return changed
}

[widget]
def slider_int2(var state : SliderStateInt2; text : string;
                format : string = "%d";
                flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = SliderInt2(text, unsafe(addr(state.value.x)), mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "slider_int2", state)
    return changed
}

[widget]
def slider_int3(var state : SliderStateInt3; text : string;
                format : string = "%d";
                flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = SliderInt3(text, unsafe(addr(state.value.x)), mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "slider_int3", state)
    return changed
}

[widget]
def slider_int4(var state : SliderStateInt4; text : string;
                format : string = "%d";
                flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = SliderInt4(text, unsafe(addr(state.value.x)), mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "slider_int4", state)
    return changed
}

[widget]
def vslider_float(var state : SliderStateFloat; text : string;
                  size : float2 = float2(40.0f, 200.0f);
                  format : string = "%.3f";
                  flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! Vertical slider; reuses SliderStateFloat. `size` is per-call (typical
    //! ~40×200 px); zero-size produces a 0×0 widget so caller-default beats
    //! struct-field-default which never fires on auto-emitted globals.
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = VSliderFloat(text, size, unsafe(addr(state.value)), mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "vslider_float", state)
    return changed
}

[widget]
def vslider_int(var state : SliderStateInt; text : string;
                size : float2 = float2(40.0f, 200.0f);
                format : string = "%d";
                flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! Vertical slider; reuses SliderStateInt. See vslider_float for `size` rationale.
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let (mn, mx) = state.bounds
    let changed = VSliderInt(text, size, unsafe(addr(state.value)), mn, mx, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "vslider_int", state)
    return changed
}

// ===== Stateful inputs (input numeric family) =====
//
// InputFloat/Int/Double don't clamp — no bounds field. Scalar forms
// expose step / step_fast (imgui's keyboard +/- buttons); vector forms
// don't (imgui doesn't support them on 2/3/4-component inputs). Int
// vectors don't take format either (imgui hardcodes "%d"). All flags
// are ImGuiInputTextFlags (NOT ImGuiSliderFlags) — Input* shares the
// text-edit widget machinery with InputText.

[widget]
def input_float(var state : InputStateFloat; text : string;
                step : float = 0.0f;
                step_fast : float = 0.0f;
                format : string = "%.3f";
                flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let changed = InputFloat(text, unsafe(addr(state.value)), step, step_fast, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "input_float", state)
    return changed
}

[widget]
def input_float2(var state : InputStateFloat2; text : string;
                 format : string = "%.3f";
                 flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let changed = InputFloat2(text, unsafe(addr(state.value.x)), format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "input_float2", state)
    return changed
}

[widget]
def input_float3(var state : InputStateFloat3; text : string;
                 format : string = "%.3f";
                 flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let changed = InputFloat3(text, unsafe(addr(state.value.x)), format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "input_float3", state)
    return changed
}

[widget]
def input_float4(var state : InputStateFloat4; text : string;
                 format : string = "%.3f";
                 flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let changed = InputFloat4(text, unsafe(addr(state.value.x)), format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "input_float4", state)
    return changed
}

[widget]
def input_int(var state : InputStateInt; text : string;
              step : int = 1;
              step_fast : int = 100;
              flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let changed = InputInt(text, unsafe(addr(state.value)), step, step_fast, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "input_int", state)
    return changed
}

[widget]
def input_int2(var state : InputStateInt2; text : string;
               flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let changed = InputInt2(text, unsafe(addr(state.value.x)), flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "input_int2", state)
    return changed
}

[widget]
def input_int3(var state : InputStateInt3; text : string;
               flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let changed = InputInt3(text, unsafe(addr(state.value.x)), flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "input_int3", state)
    return changed
}

[widget]
def input_int4(var state : InputStateInt4; text : string;
               flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let changed = InputInt4(text, unsafe(addr(state.value.x)), flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "input_int4", state)
    return changed
}

[widget]
def input_double(var state : InputStateDouble; text : string;
                 step : double = 0.0lf;
                 step_fast : double = 0.0lf;
                 format : string = "%.6f";
                 flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let changed = InputDouble(text, unsafe(addr(state.value)), step, step_fast, format, flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "input_double", state)
    return changed
}
