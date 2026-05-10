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
    @optional has_pending : bool                 // imgui_set L3 sets; render fn consumes
    @optional pending_value : float
    @optional changed : bool
}

struct SliderStateFloat2 {
    @live value : float2
    @live bounds : tuple<float; float>
    @optional has_pending : bool
    @optional pending_value : float2
    @optional changed : bool
}

struct SliderStateFloat3 {
    @live value : float3
    @live bounds : tuple<float; float>
    @optional has_pending : bool
    @optional pending_value : float3
    @optional changed : bool
}

struct SliderStateFloat4 {
    @live value : float4
    @live bounds : tuple<float; float>
    @optional has_pending : bool
    @optional pending_value : float4
    @optional changed : bool
}

struct SliderStateInt {
    @live value : int
    @live bounds : tuple<int; int>
    @optional has_pending : bool
    @optional pending_value : int
    @optional changed : bool
}

struct SliderStateInt2 {
    @live value : int2
    @live bounds : tuple<int; int>
    @optional has_pending : bool
    @optional pending_value : int2
    @optional changed : bool
}

struct SliderStateInt3 {
    @live value : int3
    @live bounds : tuple<int; int>
    @optional has_pending : bool
    @optional pending_value : int3
    @optional changed : bool
}

struct SliderStateInt4 {
    @live value : int4
    @live bounds : tuple<int; int>
    @optional has_pending : bool
    @optional pending_value : int4
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

// Drag* family. One state struct per scalar-or-vector value type the imgui
// API exposes; `bounds` is the only persistent config (zero-init = unclamped
// per ImGui's v_min==v_max semantics). `speed`, `format`, `flags` are passed
// at the call site — globals can't apply struct field defaults (they're
// zero-init), and string defaults trip the uninit-safety check. `pending_value`
// matches `value`'s type so the generic `drag_set_finalize` helper in
// imgui_widgets_builtin can capture state and steer it from imgui_set.

struct DragStateFloat {
    @live value : float
    @live bounds : tuple<float; float>           //! (min, max); zero-init = unclamped
    @optional has_pending : bool
    @optional pending_value : float
    @optional changed : bool
}

struct DragStateFloat2 {
    @live value : float2
    @live bounds : tuple<float; float>
    @optional has_pending : bool
    @optional pending_value : float2
    @optional changed : bool
}

struct DragStateFloat3 {
    @live value : float3
    @live bounds : tuple<float; float>
    @optional has_pending : bool
    @optional pending_value : float3
    @optional changed : bool
}

struct DragStateFloat4 {
    @live value : float4
    @live bounds : tuple<float; float>
    @optional has_pending : bool
    @optional pending_value : float4
    @optional changed : bool
}

struct DragStateInt {
    @live value : int
    @live bounds : tuple<int; int>
    @optional has_pending : bool
    @optional pending_value : int
    @optional changed : bool
}

struct DragStateInt2 {
    @live value : int2
    @live bounds : tuple<int; int>
    @optional has_pending : bool
    @optional pending_value : int2
    @optional changed : bool
}

struct DragStateInt3 {
    @live value : int3
    @live bounds : tuple<int; int>
    @optional has_pending : bool
    @optional pending_value : int3
    @optional changed : bool
}

struct DragStateInt4 {
    @live value : int4
    @live bounds : tuple<int; int>
    @optional has_pending : bool
    @optional pending_value : int4
    @optional changed : bool
}

struct DragStateRangeFloat {
    //! `value.x` = current_min, `value.y` = current_max. Bounds clamp both.
    //! `imgui_set {"value":[lo,hi]}` writes the whole range atomically.
    @live value : float2
    @live bounds : tuple<float; float>
    @optional has_pending : bool
    @optional pending_value : float2
    @optional changed : bool
}

struct DragStateRangeInt {
    //! `value.x` = current_min, `value.y` = current_max.
    @live value : int2
    @live bounds : tuple<int; int>
    @optional has_pending : bool
    @optional pending_value : int2
    @optional changed : bool
}

// Input* numeric family. No bounds — InputFloat/Int/Double don't clamp;
// step / step_fast / format are per-call args (uniform with Drag/Slider).
// Only `value` persists. Same has_pending/pending_value/changed shape so
// `pending_value_finalize` covers the dispatch.

struct InputStateFloat {
    @live value : float
    @optional has_pending : bool
    @optional pending_value : float
    @optional changed : bool
}

struct InputStateFloat2 {
    @live value : float2
    @optional has_pending : bool
    @optional pending_value : float2
    @optional changed : bool
}

struct InputStateFloat3 {
    @live value : float3
    @optional has_pending : bool
    @optional pending_value : float3
    @optional changed : bool
}

struct InputStateFloat4 {
    @live value : float4
    @optional has_pending : bool
    @optional pending_value : float4
    @optional changed : bool
}

struct InputStateInt {
    @live value : int
    @optional has_pending : bool
    @optional pending_value : int
    @optional changed : bool
}

struct InputStateInt2 {
    @live value : int2
    @optional has_pending : bool
    @optional pending_value : int2
    @optional changed : bool
}

struct InputStateInt3 {
    @live value : int3
    @optional has_pending : bool
    @optional pending_value : int3
    @optional changed : bool
}

struct InputStateInt4 {
    @live value : int4
    @optional has_pending : bool
    @optional pending_value : int4
    @optional changed : bool
}

struct InputStateDouble {
    @live value : double
    @optional has_pending : bool
    @optional pending_value : double
    @optional changed : bool
}

// Color* family. ColorEdit3/ColorPicker3 share ColorState3 (RGB);
// ColorEdit4/ColorPicker4 share ColorState4 (RGBA). ColorButton is
// click-only (no value stored — caller passes the color per-frame),
// so it reuses ClickState (mirrors `button` / `small_button`). `flags`
// is per-call; ImGui's color flags (DisplayHSV, Float, NoInputs, …)
// are call-site config, not persistent state.

struct ColorState3 {
    @live value : float3                         //! RGB in [0..1]
    @optional has_pending : bool
    @optional pending_value : float3
    @optional changed : bool
}

struct ColorState4 {
    @live value : float4                         //! RGBA in [0..1]
    @optional has_pending : bool
    @optional pending_value : float4
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
    //! serializer lambda stored in `g_serializers[ident]` (parallel table)
    //! when `imgui_snapshot` fires. The lambda lives outside the entry
    //! because `g_registry` is cleared every frame and we need the
    //! serializer (which captures `& state` of the per-widget global) to
    //! survive that clear.
    kind : string
    hex_id : uint
    bbox : float4                                // packed [x0, y0, x1, y1]
    @optional hover : bool
    @optional active : bool
    @optional focus : bool
}

def private widget_entry_jv(ident : string; entry : WidgetEntry) : JsonValue? {
    //! One JsonValue blob per widget. Common fields come from `entry`; the
    //! per-kind `payload` comes from `g_serializers[ident]` (the lambda the
    //! widget def registered). Same shape every kind; per-widget code never
    //! assembles JsonValue trees by hand.
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
    if (key_exists(g_serializers, ident)) {
        tab |> insert("payload", invoke(g_serializers[ident]))
    }
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

var private g_serializers : table<string; lambda<() : JsonValue?>>
var private g_dispatcher_seen : table<string; bool>

def public widget_finalize(widget_ident : string;
                           kind : string;
                           var entry : WidgetEntry;
                           var serializer : lambda<() : JsonValue?>;
                           var dispatcher : lambda<(action : string; payload : JsonValue?) : void>) {
    //! Capture common per-frame fields, register the L2/L3 dispatcher closure
    //! on first sight of `widget_ident`, and overwrite the serializer every
    //! frame. The serializer captures `& state` of the per-widget global —
    //! addresses are stable across frames so the lambda is rebuilt cheaply
    //! and the latest one is always correct. Hot-reload clears
    //! `g_dispatcher_seen` (NOT @live), so the first post-reload frame
    //! re-registers a fresh dispatcher bound to the post-reload state.
    entry.kind = kind
    entry.hex_id = GetID(widget_ident)
    let rmin = GetItemRectMin()
    let rmax = GetItemRectMax()
    entry.bbox = float4(rmin.x, rmin.y, rmax.x, rmax.y)
    entry.hover = IsItemHovered(ImGuiHoveredFlags.None)
    entry.active = IsItemActive()
    entry.focus = IsItemFocused()
    unsafe {
        g_serializers[widget_ident] <- serializer
    }
    if (!key_exists(g_dispatcher_seen, widget_ident)) {
        unsafe {
            g_dispatchers[widget_ident] <- dispatcher
        }
        g_dispatcher_seen[widget_ident] = true
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
        globals |> insert(k, widget_entry_jv(k, v))
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
