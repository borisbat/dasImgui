options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module imgui_boost_runtime shared

require imgui public
require live/live_vars public
require live/live_commands
require live_host
require daslib/json public
require daslib/json_boost

//! Runtime data layer for the dasImgui boost (Phase 0a). Holds widget state
//! struct types, the per-frame registry, and the ``[live_command]`` handlers
//! that the macro layer's emitted code feeds into.

// ===== State structs =====
//
// Each widget kind owns one struct. Mixed @live / non-@live fields:
//   - @live  → preserved across hot-reload (per Chunk A's per-field @live).
//   - plain → fresh on every reload (per-frame transient or pending-command flag).

struct ButtonState {
    @live click_count : int     //! cumulative clicks across reloads

    pending_click : bool        // queued by imgui_click L2 cmd, consumed next frame
    clicked : bool              // captured this frame

    hex_id : uint               // ImGui::GetID at render time
    bbox_min : ImVec2
    bbox_max : ImVec2
    hover : bool
    active : bool
    focus : bool
}

struct SliderStateFloat {
    @live value : float                 //! user-touched value, preserved across reload
    @live bounds : tuple<float; float>  //! (min, max) — re-init from source on reload
    @live init_value : float            //! initial value — re-init from source on reload

    has_pending : bool                  // imgui_set L3 sets this; render fn applies + clears
    pending_value : float

    hex_id : uint
    bbox_min : ImVec2
    bbox_max : ImVec2
    hover : bool
    active : bool
    focus : bool
    changed : bool
}

struct SliderStateInt {
    @live value : int
    @live bounds : tuple<int; int>
    @live init_value : int

    has_pending : bool
    pending_value : int

    hex_id : uint
    bbox_min : ImVec2
    bbox_max : ImVec2
    hover : bool
    active : bool
    focus : bool
    changed : bool
}

// ===== Per-frame registry =====
//
// One entry per render of any boost-wrapped widget, keyed by the widget's
// daslang identifier (e.g. "SAVE_BTN"). Cleared at the start of each frame.
// Phase 1 adds an RTTI walk over module globals; in Phase 0a the registry is
// the only source of truth for the snapshot command.

struct WidgetSnapshot {
    //! Per-frame snapshot of one rendered widget. The struct is fat —
    //! kind-specific fields (clicked/click_count for buttons, value_*/bounds_*
    //! for sliders) coexist; each kind fills only what applies and zero-init
    //! covers the rest. Phase 1 will swap to a per-kind variant.
    kind : string
    hex_id : uint

    bbox_x0 : float
    bbox_y0 : float
    bbox_x1 : float
    bbox_y1 : float

    hover : bool
    active : bool
    focus : bool

    // button-specific
    clicked : bool
    click_count : int

    // slider-specific
    value_float : float
    value_int : int
    bounds_min_float : float
    bounds_max_float : float
    bounds_min_int : int
    bounds_max_int : int
    changed : bool
}

var g_registry : table<string; WidgetSnapshot>
var g_frame : int = 0

def begin_frame() {
    //! Call once per frame BEFORE rendering any widgets. Bumps the frame
    //! counter and clears the per-frame registry.
    g_frame++
    g_registry |> clear()
}

// ===== Render helpers =====
//
// The macro-emitted render functions sandwich the user body between these.
// `widget_prelude` pushes the widget's identity onto the ImGui id stack so
// `GetID(label)` is uniquely scoped to the widget. `widget_postlude` captures
// post-call frame state into the snapshot and pushes it into the registry.

def widget_prelude(name : string) {
    PushID(name)
}

def widget_postlude(name : string; var snap : WidgetSnapshot) {
    snap.hex_id = GetID(name)
    let rmin = GetItemRectMin()
    let rmax = GetItemRectMax()
    snap.bbox_x0 = rmin.x
    snap.bbox_y0 = rmin.y
    snap.bbox_x1 = rmax.x
    snap.bbox_y1 = rmax.y
    snap.hover = IsItemHovered(ImGuiHoveredFlags.None)
    snap.active = IsItemActive()
    snap.focus = IsItemFocused()
    g_registry[name] = snap
    PopID()
}

// ===== [live_command] handlers =====

struct ClickArgs {
    target : string = ""
}

struct CmdResultOk {
    ok : bool = true
    queued : string = ""
}

struct CmdResultErr {
    ok : bool = false
    error : string = ""
}

def private extract_string_field(obj : JsonValue?; name : string) : string {
    //! Pull a string field out of a JSON object; returns "" if absent or not a string.
    let v = obj?[name]
    if (v == null || !(v.value is _string)) {
        return ""
    }
    return string(v.value as _string)
}

[live_command(description = "Phase 0a: full snapshot of the per-frame widget registry")]
def imgui_snapshot(input : JsonValue?) : JsonValue? {
    var globals : table<string; JsonValue?>
    for (k, v in keys(g_registry), values(g_registry)) {
        globals |> insert(k, JV(v))
    }
    return JV({"frame" => JV(g_frame), "globals" => JV(globals)})
}

// L2 click — sets pending_click on a ButtonState global. Resolution from
// target name to global happens via __imgui_click_<name> dispatch functions
// emitted per widget by the macro layer (see find_function lookup below).

[live_command(description = "Phase 0a: queue an L2 click on a button identified by 'target'")]
def imgui_click(input : JsonValue?) : JsonValue? {
    let target = extract_string_field(input, "target")
    if (target == "") {
        return JV(CmdResultErr(error = "missing 'target'"))
    }
    if (!key_exists(g_button_dispatchers, target)) {
        return JV(CmdResultErr(error = "unknown button target: {target}"))
    }
    invoke(g_button_dispatchers[target])
    return JV(CmdResultOk(queued = target))
}

// L3 set — writes pending value on a slider state global. Render fn applies
// next frame.

[live_command(description = "Phase 0a: set a slider value via L3 ('target' name + 'value')")]
def imgui_set(input : JsonValue?) : JsonValue? {
    let target = extract_string_field(input, "target")
    if (target == "") {
        return JV(CmdResultErr(error = "missing 'target'"))
    }
    if (!key_exists(g_slider_dispatchers, target)) {
        return JV(CmdResultErr(error = "unknown slider target: {target}"))
    }
    let value = input?["value"]
    invoke(g_slider_dispatchers[target], value)
    return JV(CmdResultOk(queued = target))
}

// ===== Widget dispatcher tables =====
//
// At module init, each widget registers a closure that knows how to apply a
// command to its own state global. The macro layer emits `[init]` functions
// that populate these tables. Keeping the indirection out of the live_command
// handler lets us add new widget kinds without touching this file.

var g_button_dispatchers : table<string; lambda<() : void>>
var g_slider_dispatchers : table<string; lambda<(value : JsonValue?) : void>>

def register_button_dispatcher(name : string; var fn : lambda<() : void>) {
    g_button_dispatchers[name] <- fn
}

def register_slider_dispatcher(name : string; var fn : lambda<(value : JsonValue?) : void>) {
    g_slider_dispatchers[name] <- fn
}
