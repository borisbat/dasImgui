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

//! Runtime data layer for the dasImgui boost.
//!
//! Three things live here:
//!   1. State structs the user-facing `[widget] def` blocks consume.
//!   2. The per-frame registry (`g_registry : table<string; WidgetEntry>`)
//!      and its on-demand snapshot serializer (`JV(WidgetEntry)`).
//!   3. The unified L2/L3 dispatcher table (`g_dispatchers`) plus the
//!      `imgui_click` / `imgui_set` live_command handlers that drain it.
//!
//! Per-kind detail (click_count for buttons, value/bounds for sliders) lives
//! ONLY in the per-kind state struct; the registry stores a per-widget
//! serializer lambda that reflects the state struct on demand at snapshot
//! time. Per-frame cost is one struct copy + one lambda capture; JSON only
//! materializes when `imgui_snapshot` actually fires.

// ===== Per-kind state structs =====
//
// Mixed @live (preserved across hot-reload) and @optional (transient,
// dropped from JV when zero-valued). Common per-frame imgui state — hex_id,
// bbox, hover/active/focus — lives in WidgetEntry, not here, so the structs
// stay small per kind.

struct ClickState {
    @live click_count : int                      //! cumulative across reloads
    @optional pending_click : bool               // queued by imgui_click L2; consumed next frame
    @optional clicked : bool                     // true on the frame the button fired
}

struct SliderStateFloat {
    @live value : float                          //! preserved across reload
    @live bounds : tuple<float; float>           //! (min, max)
    @live init_value : float                     //! initial value at first cold-start
    @optional has_pending : bool                 // imgui_set L3 sets; render fn consumes
    @optional pending_value : float
    @optional changed : bool
}

struct SliderStateInt {
    @live value : int
    @live bounds : tuple<int; int>
    @live init_value : int
    @optional has_pending : bool
    @optional pending_value : int
    @optional changed : bool
}

struct ToggleState {
    //! Shared across Checkbox / RadioButton (bool form) / Selectable / MenuItem.
    //! `pending_toggle` + `pending_value` let imgui_set steer the next frame's
    //! value deterministically; the renderer consumes-then-clears.
    @live value : bool
    @optional pending_toggle : bool                  // imgui_set L3 sets; consumed next frame
    @optional pending_value : bool
    @optional changed : bool                         // true on the frame the widget fired
}

struct RadioIntState {
    //! Backs RadioButton(int form). `value` is the currently-selected button
    //! id; the widget def takes the per-call `v_button` and writes value=v_button
    //! when the user clicks. `imgui_set {"value":N}` steers the selection.
    @live value : int
    @optional pending_set : bool
    @optional pending_value : int
    @optional changed : bool
}

// ===== Per-frame registry =====
//
// One entry per render of any boost-wrapped widget, keyed by the widget's
// daslang identifier ("SAVE_BTN" / "SPEED" / "VOLUME" / ...). Cleared at
// the start of each frame.

struct WidgetEntry {
    //! Per-frame snapshot of one rendered widget. Common fields populated
    //! every frame; per-kind detail is materialized on demand by the
    //! `serializer` lambda when `imgui_snapshot` fires.
    kind : string
    hex_id : uint
    bbox : float4                                // packed [x0, y0, x1, y1]
    @optional hover : bool
    @optional active : bool
    @optional focus : bool
    serializer : lambda<() : JsonValue?>
}

def public JV(entry : WidgetEntry) : JsonValue? {
    //! Custom JV overload for WidgetEntry — the generic JV() can't reflect a
    //! lambda field, and we want per-kind detail to land under "payload"
    //! produced by invoking the serializer. One overload covers every widget
    //! kind; per-widget code never assembles JsonValue trees by hand.
    var tab : table<string; JsonValue?>
    tab |> insert("kind", JV(entry.kind))
    tab |> insert("hex_id", JV(entry.hex_id))
    tab |> insert("bbox", JV(entry.bbox))
    if (entry.hover) {
        tab |> insert("hover", JV(true))
    }
    if (entry.active) {
        tab |> insert("active", JV(true))
    }
    if (entry.focus) {
        tab |> insert("focus", JV(true))
    }
    tab |> insert("payload", invoke(entry.serializer))
    return JV(tab)
}

var g_registry : table<string; WidgetEntry>
var g_frame : int = 0

def begin_frame() {
    //! Call once per frame BEFORE rendering any widgets. Bumps the frame
    //! counter and clears the per-frame registry.
    g_frame++
    g_registry |> clear()
}

// ===== Render helpers =====
//
// `widget_prelude` runs at the top of every macro-wrapped widget body
// (PushID for unique imgui scoping). `widget_finalize` runs at the bottom
// — captures the common per-frame fields, registers the lazy serializer
// + dispatcher on the first render of each ident, and balances the PushID.

def public widget_prelude(widget_ident : string) {
    PushID(widget_ident)
}

var private g_dispatcher_seen : table<string; bool>

def public widget_finalize(widget_ident : string;
                           kind : string;
                           var entry : WidgetEntry;
                           var serializer : lambda<() : JsonValue?>;
                           var dispatcher : lambda<(action : string; payload : JsonValue?) : void>) {
    //! Capture common per-frame fields, register the lazy serializer +
    //! L2/L3 dispatcher closures on first sight of `widget_ident`. Subsequent
    //! frames reuse the original closures (the captured `addr(state)` is
    //! stable across frames). Hot-reload clears `g_dispatcher_seen` (it is
    //! NOT @live), so the first post-reload frame re-registers fresh
    //! closures bound to the post-reload state addresses.
    entry.kind = kind
    entry.hex_id = GetID(widget_ident)
    let rmin = GetItemRectMin()
    let rmax = GetItemRectMax()
    entry.bbox = float4(rmin.x, rmin.y, rmax.x, rmax.y)
    entry.hover = IsItemHovered(ImGuiHoveredFlags.None)
    entry.active = IsItemActive()
    entry.focus = IsItemFocused()
    if (!key_exists(g_dispatcher_seen, widget_ident)) {
        unsafe {
            entry.serializer <- serializer
            g_dispatchers[widget_ident] <- dispatcher
        }
        g_dispatcher_seen[widget_ident] = true
    } else {
        // Already registered. Re-use the original serializer; the per-frame
        // serializer/dispatcher lambdas the caller built are dropped.
        unsafe {
            var existing <- g_registry[widget_ident].serializer
            entry.serializer <- existing
        }
    }
    g_registry[widget_ident] <- entry
    PopID()
}

// ===== L2/L3 dispatcher table =====
//
// One closure per registered widget. The closure switches on `action`
// ("click", "set", "open", "close") and applies the payload to the
// captured state global. Lazy first-frame registration via widget_finalize
// above keeps the boost's macro layer free of per-kind init emission.

var private g_dispatchers : table<string; lambda<(action : string; payload : JsonValue?) : void>>

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
    let v = obj?[name]
    if (v == null || !(v.value is _string)) {
        return ""
    }
    return string(v.value as _string)
}

[live_command(description = "Snapshot the per-frame widget registry as JSON")]
def imgui_snapshot(input : JsonValue?) : JsonValue? {
    var globals : table<string; JsonValue?>
    for (k, v in keys(g_registry), values(g_registry)) {
        globals |> insert(k, JV(v))
    }
    return JV({"frame" => JV(g_frame), "globals" => JV(globals)})
}

def private dispatch_or_err(action : string; input : JsonValue?) : JsonValue? {
    let target = extract_string_field(input, "target")
    if (target == "") {
        return JV(CmdResultErr(error = "missing 'target'"))
    }
    if (!key_exists(g_dispatchers, target)) {
        return JV(CmdResultErr(error = "unknown target: {target}"))
    }
    invoke(g_dispatchers[target], action, input)
    return JV(CmdResultOk(queued = target))
}

[live_command(description = "Queue an L2 click on a widget identified by 'target'")]
def imgui_click(input : JsonValue?) : JsonValue? {
    return dispatch_or_err("click", input)
}

[live_command(description = "Queue an L3 value set on a widget ('target' name + 'value')")]
def imgui_set(input : JsonValue?) : JsonValue? {
    return dispatch_or_err("set", input)
}

[live_command(description = "Queue an open command on a container widget ('target' name)")]
def imgui_open(input : JsonValue?) : JsonValue? {
    return dispatch_or_err("open", input)
}

[live_command(description = "Queue a close command on a container widget ('target' name)")]
def imgui_close(input : JsonValue?) : JsonValue? {
    return dispatch_or_err("close", input)
}
