options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options _allow_imgui_legacy = true

module imgui_widgets_builtin shared

require imgui public
require imgui/imgui_boost_runtime public
require imgui/imgui_boost_v2 public
require daslib/json public
require daslib/json_boost
require strings
require math

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
    let path = widget_path_key(widget_ident)
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(= path) () : JsonValue ? {
            return state_jv(path, type<typedecl(state)>)
        }
        let disp <- @ capture(= path) (action : string; payload : JsonValue ?) {
            with_state(path, type<typedecl(state)>) $(var s) {
                if (action == "click") {
                    s.pending_click = true
                }
            }
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
    register_focusable(widget_ident)
}

def private toggle_finalize(widget_ident : string; kind : string; var state : ToggleState) {
    //! Lambda + dispatcher install for bool-toggle widgets (Checkbox, RadioButton-bool,
    //! Selectable, MenuItem). Dispatcher action: "set" with bool payload.
    let path = widget_path_key(widget_ident)
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(= path) () : JsonValue ? {
            return state_jv(path, type<typedecl(state)>)
        }
        let disp <- @ capture(= path) (action : string; payload : JsonValue ?) {
            with_state(path, type<typedecl(state)>) $(var s) {
                if (action == "set") {
                    s.pending_value = payload?["value"] ?? false
                    s.pending_toggle = true
                }
            }
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
    register_focusable(widget_ident)
}

def private radio_int_finalize(widget_ident : string; kind : string; var state : RadioIntState) {
    //! Lambda + dispatcher install for the int-form RadioButton.
    //! Dispatcher action: "set" with int payload; renderer applies before the imgui call.
    let path = widget_path_key(widget_ident)
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(= path) () : JsonValue ? {
            return state_jv(path, type<typedecl(state)>)
        }
        let disp <- @ capture(= path) (action : string; payload : JsonValue ?) {
            with_state(path, type<typedecl(state)>) $(var s) {
                if (action == "set") {
                    s.pending_value = payload?["value"] ?? 0
                    s.pending_set = true
                }
            }
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
    register_focusable(widget_ident)
}

def private text_value_finalize(widget_ident : string; kind : string; var state : InputTextState) {
    // String-typed cousin of pending_value_finalize. The JsonValue payload's
    // underlying bytes drop when the dispatcher returns; we `:=` clone into
    // the widget context heap so `state.pending_value` is still valid when
    // the next widget body frame consumes it.
    let path = widget_path_key(widget_ident)
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(= path) () : JsonValue ? {
            return state_jv(path, type<typedecl(state)>)
        }
        let disp <- @ capture(= path) (action : string; payload : JsonValue ?) {
            with_state(path, type<typedecl(state)>) $(var s) {
                if (action == "set") {
                    s.pending_value := payload?["value"] ?? ""
                    s.has_pending = true
                }
            }
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
    register_focusable(widget_ident)
}

def private edit_finalize(widget_ident : string; kind : string; var ptr : auto(TT)? implicit) {
    // External-pointer finalize: serializer captures the raw pointer and
    // dereferences at snapshot time (snapshot reads `*ptr` live), dispatcher
    // writes through `*ptr` on `set`. Caller owns the pointee — pass
    // `safe_addr(local)` or `unsafe(addr(struct.field))` and accept lifetime
    // responsibility. Generic on `TT` so the same body covers every scalar
    // and vector type (`bool`/`int`/`float`/`float2`/etc.) via from_JV.
    var entry : WidgetEntry
    unsafe {
        var p = ptr
        let ser <- @ capture(= p) () : JsonValue ? {
            return JV((value = *p))
        }
        let disp <- @ capture(= p) (action : string; payload : JsonValue ?) {
            if (action == "set") {
                *p = from_JV(payload?["value"], type<TT>, default<TT>)
            }
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
    register_focusable(widget_ident)
}

// ===== Triggers (click family) =====

[widget]
def button(var state : ClickState; text : string;
           size : float2 = float2(0.0f, 0.0f)) : bool {
    let im_clicked = Button(text, ImVec2(size.x, size.y))
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
def menu_item(var state : ToggleState; text : string;
              shortcut : string = ""; enabled : bool = true) : bool {
    //! Toggleable menu item — `state.value` is the check-mark state and
    //! persists across reload; click toggles. `enabled=false` greys out
    //! the item and disables clicks. For static (non-toggleable) menu
    //! items — section headers or permanent-check labels — use the
    //! sibling `menu_label` widget instead.
    if (state.pending_toggle) {
        state.value = state.pending_value
        state.pending_toggle = false
    }
    let changed = MenuItem(text, shortcut, unsafe(addr(state.value)), enabled)
    state.changed = changed
    toggle_finalize(widget_ident, "menu_item", state)
    return changed
}

[widget]
def menu_label(var state : ClickState; text : string;
               shortcut : string = ""; selected : bool = false;
               enabled : bool = true) : bool {
    //! Static (non-toggleable) menu item. `selected` is a plain bool —
    //! renders a permanent check mark when true, no check when false; the
    //! widget never mutates it. Use for section headers
    //! (`enabled=false, selected=false`) and permanent-state labels
    //! (`selected=true`). For toggleable menu items use `menu_item`.
    //! State tracks click count for telemetry; no `state.value`.
    let im_clicked = MenuItem(text, shortcut, selected, enabled)
    var clicked = im_clicked
    if (state.pending_click) {
        state.pending_click = false
        clicked = true
    }
    state.clicked = clicked
    if (clicked) {
        state.click_count++
    }
    click_finalize(widget_ident, "menu_label", state)
    return clicked
}

[widget]
def selectable_label(var state : ClickState; text : string; selected : bool;
                     flags : ImGuiSelectableFlags = ImGuiSelectableFlags.None;
                     size : float2 = float2(0.0f, 0.0f)) : bool {
    //! Selectable row whose selected-appearance is driven by a caller-owned
    //! bool — the widget reports clicks but does not toggle its own state.
    //! Use for exclusive-selection patterns (`selectable_label(ROW[i], name,
    //! group.value == i)`) where one external int tracks the chosen index.
    //! For the self-toggling form, use `selectable` instead. Parallels
    //! `menu_label` (static) vs `menu_item` (toggling).
    let im_clicked = Selectable(text, selected, flags, size)
    var clicked = im_clicked
    if (state.pending_click) {
        state.pending_click = false
        clicked = true
    }
    state.clicked = clicked
    if (clicked) {
        state.click_count++
    }
    click_finalize(widget_ident, "selectable_label", state)
    return clicked
}

// ===== Tree leaf form =====
//
// `tree_node_ex` is the [widget] counterpart to the `tree_node` [container]:
// it wraps a bare `TreeNodeEx(text, flags)` call and returns the open bool
// without claiming a matching `TreePop()`. The caller is responsible for
// `TreePop()` when the node opened AND `flags` don't include
// `NoTreePushOnOpen` (the Leaf+NoTreePushOnOpen variant emits no push, so no
// pop is needed either).
//
// Reach for `tree_node_ex` when you need the post-header most-recent-item
// state (`IsItemClicked`, `drag_drop_source`, inline `same_line` + button) —
// the container form hides the TreeNodeEx call site so those queries would
// attach to the wrong item. For straightforward "open body, render kids,
// close" use the container.

[widget]
def tree_node_ex(var state : TreeNodeState; text : string;
                 flags : ImGuiTreeNodeFlags) : bool {
    //! Leaf-form `TreeNodeEx` — returns the open bool, caller pairs `TreePop()`
    //! manually when needed. See section comment above for when to choose this
    //! over the `tree_node` container.
    if (state.pending_open) {
        SetNextItemOpen(true, ImGuiCond.Always)
        state.pending_open = false
    }
    if (state.pending_close) {
        SetNextItemOpen(false, ImGuiCond.Always)
        state.pending_close = false
    }
    state.flags = flags
    let im_open = TreeNodeEx(text, flags)
    state.opened = im_open
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue ? {
            return JV(state)
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue ?) {
            if (action == "open") {
                state.pending_open = true
            } elif (action == "close") {
                state.pending_close = true
            }
        }
        widget_finalize(widget_ident, "tree_node_ex", entry, ser, disp)
    }
    return im_open
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

// ===== Stateful inputs (color family) =====
//
// ColorEdit3/ColorPicker3 share ColorState3 (RGB float3); ColorEdit4 /
// ColorPicker4 share ColorState4 (RGBA float4). ColorButton is a click
// trigger — caller passes the swatch color per-frame, state holds only
// click bookkeeping (reuses ClickState).

[widget]
def color_edit3(var state : ColorState3; text : string;
                flags : ImGuiColorEditFlags = ImGuiColorEditFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let changed = ColorEdit3(text, unsafe(addr(state.value.x)), flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "color_edit3", state)
    return changed
}

[widget]
def color_edit4(var state : ColorState4; text : string;
                flags : ImGuiColorEditFlags = ImGuiColorEditFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let changed = ColorEdit4(text, unsafe(addr(state.value.x)), flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "color_edit4", state)
    return changed
}

[widget]
def color_picker3(var state : ColorState3; text : string;
                  flags : ImGuiColorEditFlags = ImGuiColorEditFlags.None) : bool {
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let changed = ColorPicker3(text, unsafe(addr(state.value.x)), flags)
    state.changed = changed
    pending_value_finalize(widget_ident, "color_picker3", state)
    return changed
}

[widget]
def color_picker4(var state : ColorState4; text : string;
                  flags : ImGuiColorEditFlags = ImGuiColorEditFlags.None;
                  ref_col : float4 = float4(0.0f, 0.0f, 0.0f, 0.0f);
                  has_ref_col : bool = false) : bool {
    //! Optional reference color. Pass `has_ref_col=true` plus `ref_col`
    //! to surface ImGui's "[ref]" swatch alongside the picker; default is
    //! null (no reference). Local copy gives the addr a frame-stable
    //! address; ImGui reads ref_col synchronously inside ColorPicker4.
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    var ref_local = ref_col
    let ref_ptr = has_ref_col ? unsafe(addr(ref_local.x)) : null
    let changed = ColorPicker4(text, unsafe(addr(state.value.x)), flags, ref_ptr)
    state.changed = changed
    pending_value_finalize(widget_ident, "color_picker4", state)
    return changed
}

// ===== Stateful inputs (choice family) =====
//
// Both widgets take `items : array<string>` and marshal it C-side without
// a shim. `combo` packs a zero-separated buffer on `state.items_buf`
// (capacity reuses across frames) and reinterprets the byte addr as
// `string#` for ImGui's null-separated Combo overload — daslang `string`
// can't itself carry embedded nulls (heap is sized via strlen), but a raw
// pointer into an `array<uint8>` bypasses that entirely. `list_box` passes
// the daslang array storage directly: each `array<string>` element IS a
// `char *`, so `addr(items[0])` already matches `const char* const items[]`.
// Block-arg surfaces (BeginCombo + manual Selectable loop, BeginListBox)
// are container-shaped and land in 0b.3.

[widget]
def combo(var state : ComboState; text : string; items : array<string>;
          popup_max_height_in_items : int = -1) : bool {
    //! `imgui_set {"value": N}` selects the N-th item next frame.
    //! `popup_max_height_in_items = -1` lets ImGui pick a default.
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    state.items_buf |> clear()
    for (s in items) {
        peek_data(s) $(arr) {
            for (b in arr) {
                state.items_buf |> push(b)
            }
        }
        state.items_buf |> push(0u8)
    }
    state.items_buf |> push(0u8)            // ImGui scans for double-null = end of list
    let zsv = unsafe(reinterpret<string#>(unsafe(addr(state.items_buf[0]))))
    let changed = Combo(text, unsafe(addr(state.value)),
                        zsv, popup_max_height_in_items)
    state.changed = changed
    pending_value_finalize(widget_ident, "combo", state)
    return changed
}

[widget]
def color_button(var state : ClickState; desc_id : string;
                 col : float4;
                 size : float2 = float2(0.0f, 0.0f);
                 flags : ImGuiColorEditFlags = ImGuiColorEditFlags.None) : bool {
    //! Click-trigger swatch. The displayed color is per-call (caller
    //! controls it externally — typical use is a row of style swatches);
    //! state holds only click bookkeeping. `size = (0, 0)` lets ImGui
    //! pick a default square. Param order puts size before flags so
    //! callers can pass `(desc_id, col, size = …)` without an explicit
    //! `flags = None` middle arg (named-tuple positional dispatch).
    let im_clicked = ColorButton(desc_id, col, flags, size)
    var clicked = im_clicked
    if (state.pending_click) {
        state.pending_click = false
        clicked = true
    }
    state.clicked = clicked
    if (clicked) {
        state.click_count++
    }
    click_finalize(widget_ident, "color_button", state)
    return clicked
}

// ===== Text-input family (Phase 0b.4) =====
//
// The buffer-as-pointer path: state owns `array<uint8> buffer`, the widget
// passes `addr(buffer[0])` to the C extern, and ImGui mutates it in place.
// `value` mirrors the buffer; we re-clone after every frame ImGui reports
// `changed`. `state.buffer` is `@optional`, so it's dropped on hot-reload —
// the (re)allocate-and-sync below covers both first-frame init and post-
// reload restore.
//
// `input_text_growable` is the one callback variant we ship — uses
// `_builtin_InputText_cb` with a CallbackResize lambda that grows
// `state.buffer` past the initial capacity. All other ImGui callback
// flavors (history / completion / always / char-filter) stay in the v1
// `daslib/imgui_boost` surface.

def private input_text_buffer_init(var state : InputTextState) {
    if (length(state.buffer) != state.capacity) {
        state.buffer |> resize(state.capacity)
        sync_buffer_from_value(state)
    }
}

def private sync_buffer_from_value(var state : InputTextState) {
    // Zero the buffer then copy bytes-of-`value` (clamped to capacity-1
    // so the trailing null is preserved). `length(string)` is byte count.
    for (i in range(state.capacity)) {
        state.buffer[i] = 0u8
    }
    let want = length(state.value)
    if (want > 0) {
        let n = min(want, state.capacity - 1)
        unsafe {
            memcpy(addr(state.buffer[0]), reinterpret<void?>(state.value), n)
        }
    }
}

def private sync_value_from_buffer(var state : InputTextState) {
    unsafe {
        let pbuf = addr(state.buffer[0])
        state.value := clone_string(reinterpret<string>(pbuf))
    }
}

def private apply_pending_text(var state : InputTextState) {
    if (state.has_pending) {
        state.value := state.pending_value
        state.has_pending = false
        sync_buffer_from_value(state)
    }
}

[widget]
def input_text(var state : InputTextState; text : string;
               flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    //! Single-line text input. `imgui_set {"value":"…"}` overwrites the
    //! buffer next frame. Buffer is fixed-size (`state.capacity`, default
    //! 256). For grow-on-overflow use `input_text_growable`.
    input_text_buffer_init(state)
    apply_pending_text(state)
    let changed = _builtin_InputText_basic(unsafe(addr(state.buffer[0])), state.capacity, text, flags)
    state.changed = changed
    if (changed) {
        sync_value_from_buffer(state)
    }
    text_value_finalize(widget_ident, "input_text", state)
    return changed
}

[widget]
def input_text_with_hint(var state : InputTextState; text : string; hint : string;
                         flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    //! Same as `input_text` but renders `hint` as a placeholder when the
    //! buffer is empty.
    input_text_buffer_init(state)
    apply_pending_text(state)
    let changed = _builtin_InputTextWithHint_basic(unsafe(addr(state.buffer[0])), state.capacity, text, hint, flags)
    state.changed = changed
    if (changed) {
        sync_value_from_buffer(state)
    }
    text_value_finalize(widget_ident, "input_text_with_hint", state)
    return changed
}

[widget]
def input_text_multiline(var state : InputTextState; text : string;
                         size : float2 = float2(0.0f, 0.0f);
                         flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    //! Multi-line text input (CR/LF-tolerant). `size = (0, 0)` lets ImGui
    //! pick a default rect — typically wide-but-short. Pass an explicit
    //! size for editor-style panels.
    input_text_buffer_init(state)
    apply_pending_text(state)
    let changed = _builtin_InputTextMultiline_basic(unsafe(addr(state.buffer[0])), state.capacity, text, size, flags)
    state.changed = changed
    if (changed) {
        sync_value_from_buffer(state)
    }
    text_value_finalize(widget_ident, "input_text_multiline", state)
    return changed
}

[widget]
def input_text_growable(var state : InputTextState; text : string;
                        flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    //! Single-line input that grows `state.buffer` whenever the user types
    //! past `state.capacity`. Plumbs ImGui's CallbackResize through a daslang
    //! lambda that resizes the array and re-points `data.Buf`. The thunk
    //! holding (Context*, LineInfo*, lambda) lives on the C call stack —
    //! ImGui invokes the callback synchronously inside InputText, so no
    //! ABI pin needed. `imgui_set` with a value larger than `state.capacity`
    //! also grows — without that the user-visible "growable" promise leaks.
    input_text_buffer_init(state)
    if (state.has_pending) {
        state.value := state.pending_value
        state.has_pending = false
        let want = length(state.value) + 1
        if (want > state.capacity) {
            state.capacity = want
            state.buffer |> resize(state.capacity)
        }
        sync_buffer_from_value(state)
    }
    let cb_flags = flags | ImGuiInputTextFlags.CallbackResize
    var changed : bool
    unsafe {
        let resize_cb <- @ capture(& state) (var data : ImGuiInputTextCallbackData) : int {
            if (data.EventFlag == ImGuiInputTextFlags.CallbackResize) {
                let new_size = data.BufSize
                state.buffer |> resize(new_size)
                state.capacity = new_size
                unsafe {
                    data.Buf = reinterpret<string>(addr(state.buffer[0]))
                }
            }
            return 0
        }
        changed = _builtin_InputText_cb(addr(state.buffer[0]), state.capacity, text, cb_flags, resize_cb)
    }
    state.changed = changed
    if (changed) {
        sync_value_from_buffer(state)
    }
    text_value_finalize(widget_ident, "input_text_growable", state)
    return changed
}

[widget]
def input_text_callback(var state : InputTextState; text : string;
                        flags : ImGuiInputTextFlags;
                        cb : lambda<(var data : ImGuiInputTextCallbackData) : int>) : bool {
    //! Single-line input with a user-supplied event callback. Use this when
    //! `CallbackCompletion` (TAB completion), `CallbackHistory` (Up/Down
    //! arrow), `CallbackAlways`, or `CallbackCharFilter` is needed —
    //! the REPL pattern in `examples/imgui_demo/app_console.das` is the
    //! canonical consumer. ImGui invokes the callback synchronously inside
    //! `InputText` on the same thread; the `data` pointer is valid only
    //! for that one call. For grow-on-overflow buffer resize use
    //! `input_text_growable` instead — it wires `CallbackResize` internally
    //! and shouldn't be combined with this wrapper.
    input_text_buffer_init(state)
    apply_pending_text(state)
    var changed : bool
    unsafe {
        changed = _builtin_InputText_cb(addr(state.buffer[0]), state.capacity, text, flags, cb)
    }
    state.changed = changed
    if (changed) {
        sync_value_from_buffer(state)
    }
    text_value_finalize(widget_ident, "input_text_callback", state)
    return changed
}

// ===== Filter family =====

def private text_filter_finalize(widget_ident : string; kind : string; var state : TextFilterState) {
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue ? {
            return JV((value = state.value))
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue ?) {
            // Read-only for now. A future "set" path would mirror the
            // value back into filter.InputBuf and call filter.Build();
            // playwright doesn't drive the filter editor yet.
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
    register_focusable(widget_ident)
}

[widget]
def text_filter(var state : TextFilterState; text : string = "Filter (\"incl,-excl\") (\"error\")";
                width : float = 0.0f) : bool {
    //! Boost wrapper over `ImGuiTextFilter::Draw` — renders the inline
    //! InputText editor and parses comma-separated include/exclude
    //! tokens (`-prefix` excludes). Returns `true` on the frame the
    //! filter expression changed. Pair with `passes_filter(state, line)`
    //! in a loop to gate visible items. Empty filter = match-all.
    //! The C++ `ImGuiTextFilter` value lives inline in the state — no
    //! daslang-side buffer needed (the editor's storage is `InputBuf[256]`
    //! on the bound struct). `state.value` mirrors the editor text after
    //! every edit; on the first frame after a live-reload (when
    //! `archive::serialize` restored `state.value` but the C++ filter is
    //! zero-init), the widget body re-applies `state.value` via a fresh
    //! `ImGuiTextFilter(default_filter)` so `Draw()` and `passes_filter()`
    //! see the restored expression without forcing the user to retype.
    var buf_view : string
    unsafe {
        buf_view = reinterpret<string>(addr(state.filter.InputBuf))
    }
    if (state.value != buf_view) {
        state.filter = ImGuiTextFilter(state.value)
    }
    let changed = state.filter |> Draw(text, width)
    if (changed) {
        unsafe {
            state.value := clone_string(reinterpret<string>(addr(state.filter.InputBuf)))
        }
    }
    text_filter_finalize(widget_ident, "text_filter", state)
    return changed
}

def public passes_filter(var state : TextFilterState; line : string) : bool {
    //! Predicate companion to `text_filter`. Delegates to the hand-bound
    //! `PassFilter(filter, text)` standalone helper at
    //! `src/dasIMGUI.main.cpp:305`. While the editor is empty the
    //! underlying `Filters` `ImVector` is empty too and PassFilter returns
    //! true for all lines. NB: an exclude-only filter (e.g. `-error`) has
    //! no include terms either, so `passes_filter(state, "")` returns
    //! `true` even though the filter is active — use `is_active(state)`,
    //! not `passes_filter(state, "")`, to detect the active/inactive
    //! transition.
    return PassFilter(state.filter, line)
}

def public is_active(var state : TextFilterState) : bool {
    //! `ImGuiTextFilter::IsActive()` — true iff parsing produced at least
    //! one include OR exclude term. Use this to gate filter-active vs
    //! filter-inactive code paths (e.g. clipper-cull vs sequential scan
    //! in scrolling log views).
    return state.filter |> IsActive()
}

// ===== Combo (callback-getter) =====

[widget]
def combo_getter(var state : ComboState; text : string;
                 items_count : int;
                 getter : lambda<(idx : int; var result : string&) : bool>;
                 popup_max_height_in_items : int = -1) : bool {
    //! Procedural combo — the dropdown items are produced by a per-frame
    //! lambda instead of an `array<string>`. Useful when the list is
    //! large, virtualized, or computed (filter results, RTTI enums).
    //! `getter(idx, result)` should set `result` to the idx-th item label
    //! and return true; return false to stop. The lambda fires
    //! synchronously inside the ImGui call.
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let changed = _builtin_Combo_cb(unsafe(addr(state.value)), text, items_count,
                                    popup_max_height_in_items, getter)
    state.changed = changed
    pending_value_finalize(widget_ident, "combo_getter", state)
    return changed
}

// ===== Display: text_show =====
//
// Read-only display widget (master plan §4.3a). The standard serializer
// surfaces `state.value`, so playwright tests can `expect_value(STATUS,
// "saved")` without any extra plumbing. The dispatcher accepts "set" so
// tests can also drive the value externally — handy for setting up
// fixtures programmatically.

def private text_show_finalize(widget_ident : string; kind : string; var state : TextShowState) {
    let path = widget_path_key(widget_ident)
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(= path) () : JsonValue ? {
            return state_jv(path, type<typedecl(state)>)
        }
        let disp <- @ capture(= path) (action : string; payload : JsonValue ?) {
            with_state(path, type<typedecl(state)>) $(var s) {
                if (action == "set") {
                    s.value := payload?["value"] ?? ""
                }
            }
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
}

[widget]
def text_show(var state : TextShowState; value : string = "") {
    //! Display-only widget surfaced through telemetry. Two forms:
    //!   1. `text_show(STATUS, value="saved")` — sets state.value to the
    //!      argument every frame (call-site is the source of truth).
    //!   2. `text_show(STATUS)` — displays whatever's in state.value
    //!      (set programmatically by `STATUS.value = compute()` or
    //!      remotely via `imgui_set`).
    //! Either form serializes `state.value` for `expect_value` assertions.
    if (!empty(value)) {
        state.value := value
    }
    Text(state.value)
    text_show_finalize(widget_ident, "text_show", state)
}

// ===== Display: narrative =====
//
// Read-only display widgets that surface text or decoration to the user.
// Standard serializer (`JV(state)`) emits payload for telemetry:
//   - NarrativeState   → {value: "<text>"}
//   - LabelTextState   → {key: "<left>", value: "<right>"}
//   - EmptyMarkerState → {}  (placeholder elides at zero)
// All dispatchers are no-ops — these widgets don't accept commands.
// `register_focusable` is NOT called (display widgets are not focusable).

def private narrative_finalize(widget_ident : string; kind : string; var state : NarrativeState) {
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue ? {
            return JV(state)
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue ?) {
            // Read-only display; no L2/L3 actions.
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
}

def private label_text_finalize(widget_ident : string; kind : string; var state : LabelTextState) {
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue ? {
            return JV(state)
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue ?) {
            // Read-only display; no L2/L3 actions.
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
}

def private marker_finalize(widget_ident : string; kind : string; var state : EmptyMarkerState) {
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue ? {
            return JV(state)
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue ?) {
            // Stateless decoration; no L2/L3 actions.
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
}

[widget]
def text(var state : NarrativeState; text : string) {
    //! Plain text display. `state.value` echoes the call-site string for
    //! `expect_value(IDENT, "literal")` assertions.
    state.value := text
    TextUnformatted(text)
    narrative_finalize(widget_ident, "text", state)
}

[widget]
def text_unformatted(var state : NarrativeState; text : string) {
    //! Alias for `text` — kept for explicit clarity at call sites where the
    //! "no printf" intent matters. Identical behavior to `text`.
    state.value := text
    TextUnformatted(text)
    narrative_finalize(widget_ident, "text_unformatted", state)
}

[widget]
def text_wrapped(var state : NarrativeState; text : string) {
    //! Text wrapped to the current window or content-region width.
    state.value := text
    PushTextWrapPos(0.0f)
    TextUnformatted(text)
    PopTextWrapPos()
    narrative_finalize(widget_ident, "text_wrapped", state)
}

[widget]
def text_colored(var state : NarrativeState; color : float4; text : string) {
    //! Tinted text — `color` overrides ``ImGuiCol_Text`` for this draw.
    state.value := text
    PushStyleColor(ImGuiCol.Text, color)
    TextUnformatted(text)
    PopStyleColor(1)
    narrative_finalize(widget_ident, "text_colored", state)
}

[widget]
def text_disabled(var state : NarrativeState; text : string) {
    //! Text rendered in the disabled style (``ImGuiCol_TextDisabled``).
    state.value := text
    PushStyleColor(ImGuiCol.Text, GetStyleColorVec4(ImGuiCol.TextDisabled))
    TextUnformatted(text)
    PopStyleColor(1)
    narrative_finalize(widget_ident, "text_disabled", state)
}

[widget]
def bullet_text(var state : NarrativeState; text : string) {
    //! Bullet point followed by text — like `bullet` + `text` in one call.
    state.value := text
    Bullet()
    TextUnformatted(text)
    narrative_finalize(widget_ident, "bullet_text", state)
}

[widget]
def bullet(var state : EmptyMarkerState) {
    //! Renders a bullet glyph and stays on the current line. Follow with
    //! `same_line` + content for prefix bullets, or use `bullet_text` for
    //! "bullet + text" in one call.
    Bullet()
    marker_finalize(widget_ident, "bullet", state)
}

[widget]
def label_text(var state : LabelTextState; key : string; value : string) {
    //! Two-part display: `key` on the left in the label gutter, `value`
    //! on the right. Both echoed for telemetry. The struct field is `key`
    //! (not `label`) because `label` is reserved in gen2.
    state.key := key
    state.value := value
    LabelText(key, value)
    label_text_finalize(widget_ident, "label_text", state)
}

[widget]
def separator(var state : EmptyMarkerState) {
    //! Full-width horizontal divider line.
    Separator()
    marker_finalize(widget_ident, "separator", state)
}

[widget]
def separator_text(var state : NarrativeState; text : string) {
    //! Horizontal divider with an inline label.
    state.value := text
    SeparatorText(text)
    narrative_finalize(widget_ident, "separator_text", state)
}

// ===== Display: layout =====
//
// Cursor-repositioning primitives. They don't draw glyphs themselves but
// they ARE visible — every widget's bbox depends on where the cursor
// lands. Wrapping them as `[widget]`s lets playwright assert "button X
// is on the same row as label Y" by their telemetry idents instead of
// fragile bbox arithmetic. All four use `EmptyMarkerState` + `marker_finalize`.

[widget]
def same_line(var state : EmptyMarkerState;
              offset_from_start_x : float = 0.0f;
              spacing : float = -1.0f) {
    //! Stay on the same line as the previous widget. `offset_from_start_x`
    //! pins the next widget to that x within the current window; `spacing`
    //! is the horizontal gap (negative = use ``ItemSpacing.x`` style default).
    SameLine(offset_from_start_x, spacing)
    marker_finalize(widget_ident, "same_line", state)
}

[widget]
def new_line(var state : EmptyMarkerState) {
    //! Force a line break — undoes a preceding `same_line`.
    NewLine()
    marker_finalize(widget_ident, "new_line", state)
}

[widget]
def spacing(var state : EmptyMarkerState) {
    //! Vertical gap of one ``ItemSpacing.y`` unit.
    Spacing()
    marker_finalize(widget_ident, "spacing", state)
}

[widget]
def dummy(var state : EmptyMarkerState; size : float2) {
    //! Reserve a `size`-pixel rectangle of empty space (no draw, but the
    //! cursor advances). Useful for spacing or to consume layout columns.
    Dummy(size)
    marker_finalize(widget_ident, "dummy", state)
}

[widget]
def align_text_to_frame_padding(var state : EmptyMarkerState) {
    //! Vertically align the next text widget to fit a framed item's baseline —
    //! the standard prefix when pairing `text(...)` with an inline input or
    //! button so the label sits centred on the frame.
    AlignTextToFramePadding()
    marker_finalize(widget_ident, "align_text_to_frame_padding", state)
}

[widget]
def indent(var state : EmptyMarkerState; indent_w : float = 0.0f) {
    //! Push the cursor right by `indent_w` (or `IndentSpacing` style default
    //! when `0.0f`) for the rest of the current scope. Pair with `unindent`
    //! when done. For block-scoped indent prefer the `with_indent` wrapper.
    Indent(indent_w)
    marker_finalize(widget_ident, "indent", state)
}

[widget]
def unindent(var state : EmptyMarkerState; indent_w : float = 0.0f) {
    //! Pull the cursor left by `indent_w` (or `IndentSpacing` when `0.0f`).
    //! Pair with `indent` to bracket a section manually; for block-scoped
    //! indent prefer `with_indent`.
    Unindent(indent_w)
    marker_finalize(widget_ident, "unindent", state)
}

// ===== Display: progress / image =====
//
// Content display widgets — `progress_bar` shows a fraction in [0,1] (or
// indeterminate when `fraction < 0`); `image` blits a texture handle.
// Per-call args echo into state for telemetry; no dispatcher (read-only).

def private progress_bar_finalize(widget_ident : string; kind : string; var state : ProgressBarState) {
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue ? {
            return JV(state)
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue ?) {
            // Read-only display; no L2/L3 actions.
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
}

def private image_finalize(widget_ident : string; kind : string; var state : ImageState) {
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(& state) () : JsonValue ? {
            return JV(state)
        }
        let disp <- @ capture(& state) (action : string; payload : JsonValue ?) {
            // Read-only display; no L2/L3 actions.
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
}

[widget]
def progress_bar(var state : ProgressBarState; fraction : float;
                 size : float2 = float2(-1.0f, 0.0f);
                 overlay : string = "") {
    //! Progress bar in [0, 1]; pass a negative fraction for indeterminate
    //! animation. `size` defaults to (-1, 0) — full content-region width,
    //! one-frame-tall. `overlay` is optional center-aligned text (e.g. "42%").
    state.fraction = fraction
    state.size = size
    state.overlay := overlay
    ProgressBar(fraction, size, overlay)
    progress_bar_finalize(widget_ident, "progress_bar", state)
}

[widget]
def image(var state : ImageState; user_texture_id : void?; size : float2;
          uv0 : float2 = float2(0.0f, 0.0f);
          uv1 : float2 = float2(1.0f, 1.0f);
          tint_col : float4 = float4(1.0f, 1.0f, 1.0f, 1.0f);
          border_col : float4 = float4(0.0f, 0.0f, 0.0f, 0.0f)) {
    //! Blit `user_texture_id` (an opaque ``ImTextureID``) into a `size`-pixel
    //! rect with `uv0`/`uv1` sampling coordinates. `tint_col` modulates texel
    //! color; `border_col` draws a border (zero alpha = none). The texture
    //! handle is not part of telemetry (opaque); the rest of the args echo
    //! for snapshot assertions.
    state.size = size
    state.uv0 = uv0
    state.uv1 = uv1
    state.tint_col = tint_col
    state.border_col = border_col
    Image(user_texture_id, size, uv0, uv1, tint_col, border_col)
    image_finalize(widget_ident, "image", state)
}

// ===== Display: tooltip (flat form) =====
//
// Stateless one-liner tooltips. `set_tooltip` always shows the tooltip
// (override any previous SetTooltip in the same frame). `set_item_tooltip`
// only shows when the immediately-preceding widget is hovered — ImGui's
// `if (IsItemHovered(ForTooltip)) SetTooltip(text)` shortcut.
//
// Block-form tooltips (drawing arbitrary widgets inside the tooltip
// window) live in `imgui_containers_builtin.das` as the `tooltip` and
// `item_tooltip` [container]s. Use flat form for simple text-only popups.

[widget]
def set_tooltip(var state : NarrativeState; text : string) {
    //! Show `text` as the active tooltip; overrides any previous SetTooltip
    //! in the same frame. For hover-gated tooltips use `set_item_tooltip`.
    state.value := text
    SetTooltip(text)
    narrative_finalize(widget_ident, "set_tooltip", state)
}

[widget]
def set_item_tooltip(var state : NarrativeState; text : string;
                     flags : ImGuiHoveredFlags = ImGuiHoveredFlags.ForTooltip) {
    //! Show `text` as a tooltip when the immediately-preceding widget is
    //! hovered. Default `flags = ForTooltip` pulls per-style delay/stationary;
    //! override with `DelayNone`, `Stationary`, `DelayNormal | NoSharedDelay`
    //! etc. for custom hover semantics. ImGui's `if (IsItemHovered(flags))
    //! SetTooltip(text)` idiom — `SetItemTooltip` isn't in the daslang
    //! bindings, so we inline.
    state.value := text
    if (IsItemHovered(flags)) {
        SetTooltip(text)
    }
    narrative_finalize(widget_ident, "set_item_tooltip", state)
}

// ===== Plot lines / histogram (array form) =====
//
// Display widgets backed by `PlotState`. Plotted values come per-frame as
// an `array<float>` parameter (not stored on state) — same shape as
// daslib v1 and imgui_test_engine. State tracks last-frame's call args
// (title, bounds, sample count) for telemetry. No dispatcher.
//
// Lambda-driven getter form (plot_lines_getter / plot_histogram_getter):
// deferred to Phase 2. Audit outcome (1.6): the existing C++
// ImGuiPlotGetter struct in src/dasIMGUI.main.cpp is still wired into
// the v1 daslib/imgui_boost.das + example/imgui_demo.das via the
// older `vec4f igpg` reinterpret pattern, and per master plan §9.4 we
// keep v1 installable until users migrate. So the right move is NOT to
// rewrite the existing struct but to add a parallel lambda-thunk
// binding (mirroring 0b.4 ComboCb) when the new public API surface
// lands in Phase 2 — at which point the new boost gets its own
// _builtin_PlotLines_cb / _builtin_PlotHistogram_cb forwarders.

def private plot_finalize(widget_ident : string; kind : string; var state : PlotState) {
    let path = widget_path_key(widget_ident)
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(= path) () : JsonValue ? {
            return state_jv(path, type<typedecl(state)>)
        }
        let disp <- @ capture(= path) (action : string; payload : JsonValue ?) {
            // Plot is read-only; no L2/L3 actions. Dispatcher is a no-op.
        }
        widget_finalize(widget_ident, kind, entry, ser, disp)
    }
}

[widget]
def plot_lines(var state : PlotState; text : string;
               values : array<float>;
               scale_min : float = 3.40282347e38f;       // FLT_MAX → auto-fit
               scale_max : float = 3.40282347e38f;
               graph_size : float2 = float2(0.0f, 0.0f)) {
    state.title = text
    state.bounds = (scale_min, scale_max)
    state.samples = length(values)
    if (!empty(values)) {
        unsafe {
            imgui::PlotLines(text, addr(values[0]), length(values), 0,
                             "", scale_min, scale_max, graph_size,
                             typeinfo sizeof(type<float>))
        }
    } else {
        Text("(empty: {text})")
    }
    plot_finalize(widget_ident, "plot_lines", state)
}

[widget]
def plot_histogram(var state : PlotState; text : string;
                   values : array<float>;
                   scale_min : float = 3.40282347e38f;
                   scale_max : float = 3.40282347e38f;
                   graph_size : float2 = float2(0.0f, 0.0f)) {
    state.title = text
    state.bounds = (scale_min, scale_max)
    state.samples = length(values)
    if (!empty(values)) {
        unsafe {
            imgui::PlotHistogram(text, addr(values[0]), length(values), 0,
                                 "", scale_min, scale_max, graph_size,
                                 typeinfo sizeof(type<float>))
        }
    } else {
        Text("(empty: {text})")
    }
    plot_finalize(widget_ident, "plot_histogram", state)
}

// ===== Plot getters (callback) =====
//
// Procedural variants of plot_lines / plot_histogram — `getter(idx) :
// float` produces sample values per frame instead of a backing
// `array<float>`. Useful for synthesized signals, virtualized buffers, or
// computed series. The lambda fires synchronously inside the C call;
// thunk lifetime is bounded by the call.

[widget]
def plot_lines_getter(var state : PlotState; text : string;
                      values_count : int;
                      getter : lambda<(idx : int) : float>;
                      overlay_text : string = "";
                      scale_min : float = 3.40282347e38f;
                      scale_max : float = 3.40282347e38f;
                      graph_size : float2 = float2(0.0f, 0.0f)) {
    state.title = text
    state.bounds = (scale_min, scale_max)
    state.samples = values_count
    _builtin_PlotLines_cb(text, values_count, 0, overlay_text,
                          scale_min, scale_max, graph_size, getter)
    plot_finalize(widget_ident, "plot_lines_getter", state)
}

[widget]
def plot_histogram_getter(var state : PlotState; text : string;
                          values_count : int;
                          getter : lambda<(idx : int) : float>;
                          overlay_text : string = "";
                          scale_min : float = 3.40282347e38f;
                          scale_max : float = 3.40282347e38f;
                          graph_size : float2 = float2(0.0f, 0.0f)) {
    state.title = text
    state.bounds = (scale_min, scale_max)
    state.samples = values_count
    _builtin_PlotHistogram_cb(text, values_count, 0, overlay_text,
                              scale_min, scale_max, graph_size, getter)
    plot_finalize(widget_ident, "plot_histogram_getter", state)
}

// ===== External-pointer rail (edit_* family) =====
//
// Sibling shape to the state-backed `[widget]` defs: caller owns the value
// via `safe_addr(local)` / `unsafe(addr(struct.field))` and the renderer
// reads/writes through the pointer directly. No auto-emit, no state struct,
// no `@live` preservation — the external owner controls persistence.
// Required `id="..."` at the call site keys the telemetry path.

[edit_widget]
def edit_checkbox(var ptr : bool? implicit; text : string = "") : bool {
    //! ``Checkbox(label, ptr)`` against a caller-owned ``bool?``. Telemetry payload is ``{value}``; ``imgui_set`` writes through ``*ptr``.
    let lbl = empty(text) ? widget_ident : text
    let changed = Checkbox(lbl, ptr)
    edit_finalize(widget_ident, "edit_checkbox", ptr)
    return changed
}

[edit_widget]
def edit_radio_button(var ptr : bool? implicit; text : string = "") : bool {
    //! Bool-form ``RadioButton`` against a caller-owned ``bool?``; the widget flips ``*ptr`` on click (ImGui's RadioButton-bool doesn't mutate). For grouped int-form radios, declare a ``RadioIntState`` and use ``radio_button_int``.
    let lbl = empty(text) ? widget_ident : text
    let im_clicked = unsafe(RadioButton(lbl, *ptr))
    if (im_clicked) {
        unsafe {
            *ptr = !*ptr
        }
    }
    edit_finalize(widget_ident, "edit_radio_button", ptr)
    return im_clicked
}

[edit_widget]
def edit_slider_float(var ptr : float? implicit; text : string = "";
                      v_min : float = 0.0f; v_max : float = 1.0f;
                      format : string = "%.3f";
                      flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``SliderFloat`` against a caller-owned ``float?``. Range is per-call (no state-side ``bounds``); other args mirror :ref:`slider_float <function-imgui_widgets_builtin_slider_float_SliderStateFloat_string_string_ImGuiSliderFlags>`.
    let lbl = empty(text) ? widget_ident : text
    let changed = SliderFloat(lbl, ptr, v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_slider_float", ptr)
    return changed
}

[edit_widget]
def edit_slider_int(var ptr : int? implicit; text : string = "";
                    v_min : int = 0; v_max : int = 100;
                    format : string = "%d";
                    flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``SliderInt`` against a caller-owned ``int?``. Range is per-call.
    let lbl = empty(text) ? widget_ident : text
    let changed = SliderInt(lbl, ptr, v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_slider_int", ptr)
    return changed
}

[edit_widget]
def edit_drag_float(var ptr : float? implicit; text : string = "";
                    speed : float = 1.0f;
                    v_min : float = 0.0f; v_max : float = 0.0f;
                    format : string = "%.3f";
                    flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``DragFloat`` against a caller-owned ``float?``. ``v_min == v_max == 0`` ⇒ unbounded (ImGui convention).
    let lbl = empty(text) ? widget_ident : text
    let changed = DragFloat(lbl, ptr, speed, v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_drag_float", ptr)
    return changed
}

[edit_widget]
def edit_drag_int(var ptr : int? implicit; text : string = "";
                  speed : float = 1.0f;
                  v_min : int = 0; v_max : int = 0;
                  format : string = "%d";
                  flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``DragInt`` against a caller-owned ``int?``. ``v_min == v_max == 0`` ⇒ unbounded.
    let lbl = empty(text) ? widget_ident : text
    let changed = DragInt(lbl, ptr, speed, v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_drag_int", ptr)
    return changed
}

[edit_widget]
def edit_input_float(var ptr : float? implicit; text : string = "";
                     step : float = 0.0f;
                     step_fast : float = 0.0f;
                     format : string = "%.3f";
                     flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    //! ``InputFloat`` against a caller-owned ``float?``. No clamping (matches :ref:`input_float <function-imgui_widgets_builtin_input_float_InputStateFloat_string_float_float_string_ImGuiInputTextFlags>`); ``step``/``step_fast`` drive the ±buttons.
    let lbl = empty(text) ? widget_ident : text
    let changed = InputFloat(lbl, ptr, step, step_fast, format, flags)
    edit_finalize(widget_ident, "edit_input_float", ptr)
    return changed
}

[edit_widget]
def edit_input_int(var ptr : int? implicit; text : string = "";
                   step : int = 1;
                   step_fast : int = 100;
                   flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    //! ``InputInt`` against a caller-owned ``int?``. No clamping.
    let lbl = empty(text) ? widget_ident : text
    let changed = InputInt(lbl, ptr, step, step_fast, flags)
    edit_finalize(widget_ident, "edit_input_int", ptr)
    return changed
}

// ===== External-pointer rail (10b: vectors) =====
//
// Vector overloads (float2/3/4 + int2/3/4) for slider and drag. Each
// `T2?`/`T3?`/`T4?` pointer is reinterpret-cast to `T?` at the ImGui call
// site since ImGui's Slider* / Drag* family signatures all take a single
// `T*` and treat it as a contiguous 2/3/4-component layout — no separate
// vector binding. `edit_finalize` still takes the full vector pointer so
// the serializer/dispatcher round-trip the whole tuple via from_JV.

[edit_widget]
def edit_slider_float2(var ptr : float2? implicit; text : string = "";
                       v_min : float = 0.0f; v_max : float = 1.0f;
                       format : string = "%.3f";
                       flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``SliderFloat2`` against a caller-owned ``float2?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = SliderFloat2(lbl, unsafe(reinterpret<float?>(ptr)),
                               v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_slider_float2", ptr)
    return changed
}

[edit_widget]
def edit_slider_float3(var ptr : float3? implicit; text : string = "";
                       v_min : float = 0.0f; v_max : float = 1.0f;
                       format : string = "%.3f";
                       flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``SliderFloat3`` against a caller-owned ``float3?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = SliderFloat3(lbl, unsafe(reinterpret<float?>(ptr)),
                               v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_slider_float3", ptr)
    return changed
}

[edit_widget]
def edit_slider_float4(var ptr : float4? implicit; text : string = "";
                       v_min : float = 0.0f; v_max : float = 1.0f;
                       format : string = "%.3f";
                       flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``SliderFloat4`` against a caller-owned ``float4?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = SliderFloat4(lbl, unsafe(reinterpret<float?>(ptr)),
                               v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_slider_float4", ptr)
    return changed
}

[edit_widget]
def edit_slider_int2(var ptr : int2? implicit; text : string = "";
                     v_min : int = 0; v_max : int = 100;
                     format : string = "%d";
                     flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``SliderInt2`` against a caller-owned ``int2?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = SliderInt2(lbl, unsafe(reinterpret<int?>(ptr)),
                             v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_slider_int2", ptr)
    return changed
}

[edit_widget]
def edit_slider_int3(var ptr : int3? implicit; text : string = "";
                     v_min : int = 0; v_max : int = 100;
                     format : string = "%d";
                     flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``SliderInt3`` against a caller-owned ``int3?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = SliderInt3(lbl, unsafe(reinterpret<int?>(ptr)),
                             v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_slider_int3", ptr)
    return changed
}

[edit_widget]
def edit_slider_int4(var ptr : int4? implicit; text : string = "";
                     v_min : int = 0; v_max : int = 100;
                     format : string = "%d";
                     flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``SliderInt4`` against a caller-owned ``int4?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = SliderInt4(lbl, unsafe(reinterpret<int?>(ptr)),
                             v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_slider_int4", ptr)
    return changed
}

[edit_widget]
def edit_drag_float2(var ptr : float2? implicit; text : string = "";
                     speed : float = 1.0f;
                     v_min : float = 0.0f; v_max : float = 0.0f;
                     format : string = "%.3f";
                     flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``DragFloat2`` against a caller-owned ``float2?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = DragFloat2(lbl, unsafe(reinterpret<float?>(ptr)),
                             speed, v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_drag_float2", ptr)
    return changed
}

[edit_widget]
def edit_drag_float3(var ptr : float3? implicit; text : string = "";
                     speed : float = 1.0f;
                     v_min : float = 0.0f; v_max : float = 0.0f;
                     format : string = "%.3f";
                     flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``DragFloat3`` against a caller-owned ``float3?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = DragFloat3(lbl, unsafe(reinterpret<float?>(ptr)),
                             speed, v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_drag_float3", ptr)
    return changed
}

[edit_widget]
def edit_drag_float4(var ptr : float4? implicit; text : string = "";
                     speed : float = 1.0f;
                     v_min : float = 0.0f; v_max : float = 0.0f;
                     format : string = "%.3f";
                     flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``DragFloat4`` against a caller-owned ``float4?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = DragFloat4(lbl, unsafe(reinterpret<float?>(ptr)),
                             speed, v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_drag_float4", ptr)
    return changed
}

[edit_widget]
def edit_drag_int2(var ptr : int2? implicit; text : string = "";
                   speed : float = 1.0f;
                   v_min : int = 0; v_max : int = 0;
                   format : string = "%d";
                   flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``DragInt2`` against a caller-owned ``int2?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = DragInt2(lbl, unsafe(reinterpret<int?>(ptr)),
                           speed, v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_drag_int2", ptr)
    return changed
}

[edit_widget]
def edit_drag_int3(var ptr : int3? implicit; text : string = "";
                   speed : float = 1.0f;
                   v_min : int = 0; v_max : int = 0;
                   format : string = "%d";
                   flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``DragInt3`` against a caller-owned ``int3?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = DragInt3(lbl, unsafe(reinterpret<int?>(ptr)),
                           speed, v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_drag_int3", ptr)
    return changed
}

[edit_widget]
def edit_drag_int4(var ptr : int4? implicit; text : string = "";
                   speed : float = 1.0f;
                   v_min : int = 0; v_max : int = 0;
                   format : string = "%d";
                   flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``DragInt4`` against a caller-owned ``int4?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = DragInt4(lbl, unsafe(reinterpret<int?>(ptr)),
                           speed, v_min, v_max, format, flags)
    edit_finalize(widget_ident, "edit_drag_int4", ptr)
    return changed
}

// ===== External-pointer rail (10c: input vectors, color, combo, special) =====
//
// Remaining external-pointer overloads: ``input_*`` vector forms (no clamp,
// 2/3/4 component), ``input_double`` scalar, the color family (3/4 + picker
// variants), ``combo`` (array-of-string-pointers form so no per-frame buffer
// packing — the C side reads ``items[i]`` lazily), plus ``slider_angle``
// (float radians, displayed degrees) and ``checkbox_flags`` (bit-mask
// toggle on an ``int?``).

[edit_widget]
def edit_input_float2(var ptr : float2? implicit; text : string = "";
                      format : string = "%.3f";
                      flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    //! ``InputFloat2`` against a caller-owned ``float2?``. No clamping.
    let lbl = empty(text) ? widget_ident : text
    let changed = InputFloat2(lbl, unsafe(reinterpret<float?>(ptr)), format, flags)
    edit_finalize(widget_ident, "edit_input_float2", ptr)
    return changed
}

[edit_widget]
def edit_input_float3(var ptr : float3? implicit; text : string = "";
                      format : string = "%.3f";
                      flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    //! ``InputFloat3`` against a caller-owned ``float3?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = InputFloat3(lbl, unsafe(reinterpret<float?>(ptr)), format, flags)
    edit_finalize(widget_ident, "edit_input_float3", ptr)
    return changed
}

[edit_widget]
def edit_input_float4(var ptr : float4? implicit; text : string = "";
                      format : string = "%.3f";
                      flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    //! ``InputFloat4`` against a caller-owned ``float4?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = InputFloat4(lbl, unsafe(reinterpret<float?>(ptr)), format, flags)
    edit_finalize(widget_ident, "edit_input_float4", ptr)
    return changed
}

[edit_widget]
def edit_input_int2(var ptr : int2? implicit; text : string = "";
                    flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    //! ``InputInt2`` against a caller-owned ``int2?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = InputInt2(lbl, unsafe(reinterpret<int?>(ptr)), flags)
    edit_finalize(widget_ident, "edit_input_int2", ptr)
    return changed
}

[edit_widget]
def edit_input_int3(var ptr : int3? implicit; text : string = "";
                    flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    //! ``InputInt3`` against a caller-owned ``int3?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = InputInt3(lbl, unsafe(reinterpret<int?>(ptr)), flags)
    edit_finalize(widget_ident, "edit_input_int3", ptr)
    return changed
}

[edit_widget]
def edit_input_int4(var ptr : int4? implicit; text : string = "";
                    flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    //! ``InputInt4`` against a caller-owned ``int4?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = InputInt4(lbl, unsafe(reinterpret<int?>(ptr)), flags)
    edit_finalize(widget_ident, "edit_input_int4", ptr)
    return changed
}

[edit_widget]
def edit_input_double(var ptr : double? implicit; text : string = "";
                      step : double = 0.0lf;
                      step_fast : double = 0.0lf;
                      format : string = "%.6f";
                      flags : ImGuiInputTextFlags = ImGuiInputTextFlags.None) : bool {
    //! ``InputDouble`` against a caller-owned ``double?``.
    let lbl = empty(text) ? widget_ident : text
    let changed = InputDouble(lbl, ptr, step, step_fast, format, flags)
    edit_finalize(widget_ident, "edit_input_double", ptr)
    return changed
}

[edit_widget]
def edit_color_edit3(var ptr : float3? implicit; text : string = "";
                     flags : ImGuiColorEditFlags = ImGuiColorEditFlags.None) : bool {
    //! ``ColorEdit3`` against a caller-owned ``float3?`` (RGB).
    let lbl = empty(text) ? widget_ident : text
    let changed = ColorEdit3(lbl, unsafe(reinterpret<float?>(ptr)), flags)
    edit_finalize(widget_ident, "edit_color_edit3", ptr)
    return changed
}

[edit_widget]
def edit_color_edit4(var ptr : float4? implicit; text : string = "";
                     flags : ImGuiColorEditFlags = ImGuiColorEditFlags.None) : bool {
    //! ``ColorEdit4`` against a caller-owned ``float4?`` (RGBA).
    let lbl = empty(text) ? widget_ident : text
    let changed = ColorEdit4(lbl, unsafe(reinterpret<float?>(ptr)), flags)
    edit_finalize(widget_ident, "edit_color_edit4", ptr)
    return changed
}

[edit_widget]
def edit_color_picker3(var ptr : float3? implicit; text : string = "";
                       flags : ImGuiColorEditFlags = ImGuiColorEditFlags.None) : bool {
    //! ``ColorPicker3`` against a caller-owned ``float3?`` (RGB).
    let lbl = empty(text) ? widget_ident : text
    let changed = ColorPicker3(lbl, unsafe(reinterpret<float?>(ptr)), flags)
    edit_finalize(widget_ident, "edit_color_picker3", ptr)
    return changed
}

[edit_widget]
def edit_color_picker4(var ptr : float4? implicit; text : string = "";
                       flags : ImGuiColorEditFlags = ImGuiColorEditFlags.None;
                       ref_col : float4 = float4(0.0f, 0.0f, 0.0f, 0.0f);
                       has_ref_col : bool = false) : bool {
    //! ``ColorPicker4`` against a caller-owned ``float4?`` (RGBA). Optional reference swatch via ``has_ref_col`` + ``ref_col``.
    let lbl = empty(text) ? widget_ident : text
    var ref_local = ref_col
    let ref_ptr = has_ref_col ? unsafe(addr(ref_local.x)) : null
    let changed = ColorPicker4(lbl, unsafe(reinterpret<float?>(ptr)), flags, ref_ptr)
    edit_finalize(widget_ident, "edit_color_picker4", ptr)
    return changed
}

[edit_widget]
def edit_combo(var ptr : int? implicit; text : string = "";
               items : array<string>;
               popup_max_height_in_items : int = -1) : bool {
    //! ``Combo`` against a caller-owned ``int?`` index. ``items`` is passed as an array of C-string pointers (no per-frame zero-separated buffer; daslang ``string`` already carries the trailing null).
    let lbl = empty(text) ? widget_ident : text
    let changed = Combo(lbl, ptr, unsafe(addr(items[0])), length(items),
                        popup_max_height_in_items)
    edit_finalize(widget_ident, "edit_combo", ptr)
    return changed
}

[edit_widget]
def edit_slider_angle(var ptr : float? implicit; text : string = "";
                      v_degrees_min : float = -360.0f;
                      v_degrees_max : float = 360.0f;
                      format : string = "%.0f deg";
                      flags : ImGuiSliderFlags = ImGuiSliderFlags.None) : bool {
    //! ``SliderAngle`` against a caller-owned ``float?`` (radians on the pointer side; degrees on the UI side).
    let lbl = empty(text) ? widget_ident : text
    let changed = SliderAngle(lbl, ptr, v_degrees_min, v_degrees_max, format, flags)
    edit_finalize(widget_ident, "edit_slider_angle", ptr)
    return changed
}

[edit_widget]
def edit_checkbox_flags(var ptr : int? implicit; text : string = "";
                        flags_value : int = 0) : bool {
    //! ``CheckboxFlags`` against a caller-owned ``int?`` bitfield; toggles the ``flags_value`` bit. Payload serializes the underlying ``int``; visual state on the bit is implicit.
    let lbl = empty(text) ? widget_ident : text
    let changed = CheckboxFlags(lbl, ptr, flags_value)
    edit_finalize(widget_ident, "edit_checkbox_flags", ptr)
    return changed
}

[edit_widget]
def edit_collapsing_header(var ptr : bool? implicit; text : string = "";
                           flags : ImGuiTreeNodeFlags = ImGuiTreeNodeFlags.None) : bool {
    //! ``CollapsingHeader(label, p_visible, flags)`` against a caller-owned
    //! ``bool?`` p_open. While ``*ptr == false`` the header (and its body)
    //! is hidden entirely. While ``*ptr == true`` the X close-button on the
    //! header writes ``*ptr = false`` when clicked. Body of the
    //! conditional ``if (edit_collapsing_header(...))`` runs only when the
    //! section is both visible AND expanded. The state-owned sibling is the
    //! ``collapsing_header(closable=true)`` container.
    let lbl = empty(text) ? widget_ident : text
    var im_open : bool = false
    if (unsafe(*ptr)) {
        im_open = CollapsingHeader(lbl, ptr, flags)
    }
    edit_finalize(widget_ident, "edit_collapsing_header", ptr)
    return im_open
}

// ===== Imperative commands (scroll / focus / clipboard) =====
//
// These are non-`[widget]` helpers — plain `def public` aliases over raw
// ImGui calls that user code shouldn't reach for directly under the
// default-on lint. They take no block and produce no state, so they
// don't fit the [widget] / [container] mold.

def public set_scroll_here_y(center_y_ratio : float = 1.0f) {
    //! `SetScrollHereY(center_y_ratio)` — scrolls the current window so the
    //! recently-submitted item is anchored at the given vertical ratio
    //! (0=top, 0.5=middle, 1=bottom). Common pattern: tail-follow scrolling
    //! regions call `set_scroll_here_y(1.0f)` after the last entry.
    SetScrollHereY(center_y_ratio)
}

def public set_keyboard_focus_here(offset : int = 0) {
    //! `SetKeyboardFocusHere(offset)` — moves keyboard focus to the
    //! item N items ahead (`offset = 0`) or behind (`offset = -1`, the
    //! item that was just submitted). REPL-style inputs use `-1` after
    //! Enter to refocus the editbox for the next command.
    SetKeyboardFocusHere(offset)
}

def public set_item_default_focus() {
    //! `SetItemDefaultFocus()` — marks the previous item as the default
    //! focus target on first frame of a window. Used on the primary input
    //! widget so the user can start typing immediately.
    SetItemDefaultFocus()
}

def public log_to_clipboard(auto_open_depth : int = -1) {
    //! `LogToClipboard(auto_open_depth)` — starts capturing subsequent
    //! text-emitting widgets to the OS clipboard until `log_finish()` is
    //! called. `auto_open_depth = -1` means capture all depths.
    LogToClipboard(auto_open_depth)
}

def public log_finish() {
    //! `LogFinish()` — stops the active log capture started by
    //! `log_to_clipboard` (or any other `LogTo*` call) and finalizes the
    //! clipboard contents.
    LogFinish()
}
