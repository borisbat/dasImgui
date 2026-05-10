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
require daslib/json_boost public
require strings

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

// Choice family. `value` is the selected item index; `imgui_set {"value":N}`
// steers the next-frame selection. The user passes `items : array<string>`
// per-frame; combo/list_box marshal it C-side without a shim:
//   - combo packs a zero-separated `array<uint8>` (kept on state for capacity
//     reuse) and reinterprets `addr(buf[0])` as `string#` for ImGui's
//     null-separated overload.
//   - list_box passes `addr(items[0])` directly — daslang `array<string>`
//     storage is `char **`, which matches ImGui's `const char* const items[]`.
// BeginCombo/EndCombo + BeginListBox/EndListBox (block-arg manual loop) roll
// into 0b.3 with the rest of the [container] family.

struct ComboState {
    @live value : int = -1                       //! selected index, -1 = none
    @optional has_pending : bool
    @optional pending_value : int
    @optional changed : bool
    @optional items_buf : array<uint8>           // transient zero-separated buffer; rebuilt each frame
}

struct ListBoxState {
    @live value : int = -1                       //! selected index, -1 = none
    @optional has_pending : bool
    @optional pending_value : int
    @optional changed : bool
}

// Text-input family. The buffer is the canonical storage; `value` is the
// extracted (clone-on-change) string presented to user code.
// `input_text_growable` reuses this struct; its CallbackResize lambda
// updates `capacity` + `buffer` in place.

struct InputTextState {
    @live value : string = ""                             //! current text content (clone of buffer)
    @live capacity : int = 256                            //! working buffer size in bytes (incl. trailing null)
    @optional has_pending : bool
    @optional pending_value : string = ""
    @optional changed : bool
    @optional buffer : array<uint8>                       // working buffer; mirrors `value`, allocated to capacity on first frame / post-reload
}

// ===== Container family (Phase 0b.3) =====
//
// `[container]` widgets wrap a daslang block argument and push themselves onto
// `g_container_path` so leaf children get hierarchical registry keys. Per-kind
// state captures only what's worth remembering across frames + reloads — open
// state for togglable containers, layout dims for windows / children, flags
// for everything that takes them. Stateless containers (group, menu_bar,
// tooltip, item_tooltip) get an empty struct so the [widget] auto-emit gate
// still has something to instantiate.

struct WindowState {
    //! Backs the `window` container. `open` defaults to true so a closable
    //! window renders from frame 1; the X-button or `imgui_close` flips it
    //! false. `@live` carries that across reload. Everything else is per-
    //! frame observed (pos/size/collapsed) or echoed from per-call args
    //! (flags). ImGui persists window pos itself via imgui.ini, so
    //! duplicating it as `@live` would only fight that. `imgui_open` /
    //! `imgui_close` flow through pending_open/close; the renderer applies
    //! them at the top of the next frame. Per-call config (closable, flags)
    //! is supplied via the named-tuple at the call site — same convention
    //! as `[widget]`.
    @live open : bool = true
    @optional flags : ImGuiWindowFlags
    @optional pos : float2
    @optional size : float2
    @optional collapsed : bool
    @optional pending_open : bool
    @optional pending_close : bool
}

struct ChildState {
    //! Backs the `child` container. All fields are observed (scroll); per-
    //! call config (size, child_flags, window_flags) is supplied via the
    //! named-tuple at the call site.
    @optional size : float2
    @optional child_flags : ImGuiChildFlags
    @optional window_flags : ImGuiWindowFlags
    @optional scroll : float2
}

struct GroupState {
    //! Backs the `group` container. Pure layout grouping — no persistent or
    //! observable state, but the [container] macro still needs a struct to
    //! hang the auto-emitted global on. The `_placeholder` field stays
    //! @optional so JV(state) emits `{}` when the group is rendered.
    @optional _placeholder : bool
}

struct MenuBarState {
    //! Backs the `menu_bar` container. Stateless wrapper.
    @optional _placeholder : bool
}

struct MenuState {
    //! Backs the `menu` container — a single drop-down inside a menu bar.
    //! `enabled` is per-call; `opened` is per-frame observed.
    @optional enabled : bool
    @optional opened : bool
}

struct PopupState {
    //! Shared by `popup` and `popup_modal`. `open` is @live so the user-driven
    //! state survives reload. `imgui_open` / `imgui_close` route through
    //! pending_open/close; the renderer issues OpenPopup/CloseCurrentPopup
    //! on the next frame in response.
    @live open : bool
    @optional flags : ImGuiWindowFlags
    @optional pending_open : bool
    @optional pending_close : bool
}

struct TabBarState {
    //! Backs the `tab_bar` container. ImGui drives active-tab selection
    //! itself; we just observe.
    @optional flags : ImGuiTabBarFlags
}

struct TabItemState {
    //! Backs the `tab_item` container. `open` defaults to true so a closable
    //! tab renders from frame 1; the X-button or `imgui_close` flips it false.
    //! `@live` carries that across reload.
    @live open : bool = true
    @optional flags : ImGuiTabItemFlags
    @optional pending_open : bool
    @optional pending_close : bool
}

struct TooltipState {
    //! Backs both `tooltip` and `item_tooltip`. Tooltips don't persist —
    //! they're a per-frame chrome pop.
    @optional _placeholder : bool
}

struct TreeNodeState {
    //! Backs the `tree_node` container. ImGui owns the open/close state
    //! internally; we mirror what's observable so snapshots reflect truth,
    //! and the dispatcher routes open/close through SetNextItemOpen.
    @optional flags : ImGuiTreeNodeFlags
    @optional opened : bool                       // observed per-frame: TreeNode returned true
    @optional pending_open : bool
    @optional pending_close : bool
}

struct CollapsingHeaderState {
    //! Backs the `collapsing_header` container. Same shape as TreeNodeState
    //! since the imgui call structurally mirrors it (returns bool, no End()).
    @optional flags : ImGuiTreeNodeFlags
    @optional opened : bool
    @optional pending_open : bool
    @optional pending_close : bool
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

// ===== Long-lived widget registry (Phase 1) =====
//
// `g_widgets` is the long-lived twin of `g_registry`. The [widget] macro
// emits a `register_widget(...)` call into a per-module shared `[init]`
// function (see daslib/decs_boost.das:583-589 for the setup_call_list
// pattern), so every widget appears here at module load — even before its
// containing window/tab is opened.
//
// `imgui_snapshot` walks `g_widgets` for the full widget enumeration and
// joins each entry with `g_registry[k]` for this frame's bbox / hover /
// active / focus when present. Closed-window widgets surface with
// `rendered: false` and the state struct's serializer payload.
//
// Keying: registration uses the widget's bare ident (the macro can't
// know the container chain at expansion time when the user's container
// is hidden behind helpers). On first render `widget_finalize` migrates
// the entry from `bareName` to `path_key` (container-aware) so siblings
// across containers stay distinct.

struct WidgetMeta {
    module_name : string
    kind : string
    state_addr : void?
    serializer : lambda<() : JsonValue?>
    last_seen_frame : int
}

var g_widgets : table<string; WidgetMeta>

// ===== Container path stack =====
//
// `g_container_path` is the chain of currently-open `[container]` idents,
// outermost-first. Pushed on container body entry, popped on body exit. Leaf
// widgets read the chain at finalize time to build hierarchical registry +
// dispatcher keys ("MAIN_WIN/SETTINGS_TAB/RPS"). Containers themselves push
// before invoking their block, so by the time their body calls
// container_finalize, self is already at the chain's tail.
//
// `g_container_path_str` is the cached "/"-joined form, kept in sync by
// push/pop so leaf finalize is one string interpolation rather than an
// O(depth) join per leaf per frame.

var g_container_path : array<string>
var private g_container_path_str : string

def public container_path_push(widget_ident : string) {
    //! Append `widget_ident` to the open-container chain. Called by the
    //! `[container]` macro at the top of every wrapped body. The matching
    //! `container_path_pop` lives in body.finalList so it runs even on early
    //! return (panic still skips it — same risk surface as widget_finalize).
    g_container_path |> push(widget_ident)
    if (length(g_container_path) == 1) {
        g_container_path_str = widget_ident
    } else {
        g_container_path_str = "{g_container_path_str}/{widget_ident}"
    }
}

def public container_path_pop() {
    //! Pop the tail container ident. Idempotent on empty (defensive — a panic
    //! mid-frame followed by a recovery would otherwise leak).
    return if (empty(g_container_path))
    g_container_path |> pop()
    if (empty(g_container_path)) {
        g_container_path_str = ""
    } else {
        // Rebuild via build_string — pop is O(depth) anyway; avoid the O(depth^2)
        // allocation churn of a chain of `s = "{s}/.."` interpolations.
        g_container_path_str = build_string() $(var w) {
            for (i in range(length(g_container_path))) {
                if (i > 0) {
                    w |> write("/")
                }
                w |> write(g_container_path[i])
            }
        }
    }
}

def public widget_path_key(widget_ident : string) : string {
    //! Build the registry/dispatcher key for a leaf widget: the open container
    //! chain joined by "/" then the leaf's own ident. Empty container path
    //! degrades to bare ident — preserves pre-0b.3 behavior for unnested widgets.
    return widget_ident if (empty(g_container_path_str))
    return "{g_container_path_str}/{widget_ident}"
}

def public container_path_key() : string {
    //! Build the registry/dispatcher key for a container's own entry. The
    //! container has already pushed itself onto `g_container_path`, so the
    //! cached path string is the answer directly.
    return g_container_path_str
}

def begin_frame() {
    //! Call once per frame BEFORE rendering any widgets. Bumps the frame
    //! counter and clears the per-frame registry. Also defensively clears
    //! the container path — a panic mid-frame the previous tick would
    //! otherwise leave a stale chain.
    g_frame++
    g_registry |> clear()
    if (!empty(g_container_path)) {
        g_container_path |> clear()
        g_container_path_str = ""
    }
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

def public clear_module_widgets(module_name : string) {
    //! Erase every g_widgets entry tagged with this module. Called as the
    //! first line of each user module's `register`imgui`widgets()` [init]
    //! function (prepended by the [widget] macro on first widget per
    //! module). On hot-reload, the [init] re-fires → clear-then-refill
    //! drops widgets removed from source AND replaces lambdas with fresh
    //! closures bound to post-reload state addresses. Entries from other
    //! modules are untouched.
    var to_remove : array<string>
    for (k, m in keys(g_widgets), values(g_widgets)) {
        if (m.module_name == module_name) {
            to_remove |> push(k)
        }
    }
    for (k in to_remove) {
        g_widgets |> erase(k)
    }
}

def public register_widget(module_name : string;
                           bare_ident : string;
                           kind : string;
                           state_addr : void?;
                           var serializer : lambda<() : JsonValue?>) {
    //! Module-init registration into the long-lived `g_widgets` table.
    //! Called from the per-module `[init]` function the [widget] macro
    //! builds via setup_call_list. Keyed on bare ident; on first render
    //! `widget_finalize` migrates the entry to its container-aware
    //! path_key. The entry is tagged with `module_name` so reloads can
    //! clear-then-refill via `clear_module_widgets` (see above).
    unsafe {
        g_widgets[bare_ident] <- WidgetMeta(
            module_name = module_name,
            kind = kind,
            state_addr = state_addr,
            serializer <- serializer,
            last_seen_frame = -1
        )
    }
}

var private g_serializers : table<string; lambda<() : JsonValue?>>
var private g_dispatcher_seen : table<string; bool>

def public widget_finalize(widget_ident : string;
                           kind : string;
                           var entry : WidgetEntry;
                           var serializer : lambda<() : JsonValue?>;
                           var dispatcher : lambda<(action : string; payload : JsonValue?) : void>) {
    //! Capture common per-frame fields, register the L2/L3 dispatcher closure
    //! on first sight of the path key, and overwrite the serializer every
    //! frame. The serializer captures `& state` of the per-widget global —
    //! addresses are stable across frames so the lambda is rebuilt cheaply
    //! and the latest one is always correct. Hot-reload clears
    //! `g_dispatcher_seen` (NOT @live), so the first post-reload frame
    //! re-registers a fresh dispatcher bound to the post-reload state.
    //! Path key includes any open `[container]` ancestors (0b.3) — sibling
    //! idents under different containers map to distinct addresses.
    let path_key = widget_path_key(widget_ident)
    entry.kind = kind
    entry.hex_id = GetID(widget_ident)
    let rmin = GetItemRectMin()
    let rmax = GetItemRectMax()
    entry.bbox = float4(rmin.x, rmin.y, rmax.x, rmax.y)
    entry.hover = IsItemHovered(ImGuiHoveredFlags.None)
    entry.active = IsItemActive()
    entry.focus = IsItemFocused()
    unsafe {
        g_serializers[path_key] <- serializer
    }
    if (!key_exists(g_dispatcher_seen, path_key)) {
        unsafe {
            g_dispatchers[path_key] <- dispatcher
        }
        g_dispatcher_seen[path_key] = true
    }
    g_registry[path_key] <- entry
    widgets_mark_seen(widget_ident, path_key)
    PopID()
}

def private widgets_mark_seen(bare_ident : string; path_key : string) {
    //! Phase 1: the [widget] macro registered this widget under its bare
    //! ident at module init. On first render we know the container-aware
    //! path_key and migrate the entry. Subsequent renders just bump
    //! last_seen_frame. If neither key is present (user wrote a [widget]
    //! body without going through the macro — e.g. tests calling
    //! widget_finalize directly), do nothing.
    if (bare_ident != path_key && key_exists(g_widgets, bare_ident)) {
        var moved <- g_widgets[bare_ident]
        g_widgets |> erase(bare_ident)
        unsafe {
            g_widgets[path_key] <- moved
        }
    }
    if (key_exists(g_widgets, path_key)) {
        g_widgets[path_key].last_seen_frame = g_frame
    }
}

def public container_finalize(widget_ident : string;
                              kind : string;
                              var entry : WidgetEntry;
                              var serializer : lambda<() : JsonValue?>;
                              var dispatcher : lambda<(action : string; payload : JsonValue?) : void>) {
    //! Container counterpart of widget_finalize. Self is already at the tail
    //! of g_container_path (the [container] macro's prelude pushed it before
    //! the user body ran), so the path key is the cached chain string itself.
    //! Containers don't capture bbox/hover/active/focus — those imgui
    //! introspection calls aren't meaningful at the End-pair scope (the
    //! "current item" is whatever ran last inside the body, not the
    //! container). Per-kind state (window pos/size, popup open, …) lives in
    //! the state struct and is reflected through `serializer`.
    let path_key = container_path_key()
    entry.kind = kind
    entry.hex_id = GetID(widget_ident)
    unsafe {
        g_serializers[path_key] <- serializer
    }
    if (!key_exists(g_dispatcher_seen, path_key)) {
        unsafe {
            g_dispatchers[path_key] <- dispatcher
        }
        g_dispatcher_seen[path_key] = true
    }
    g_registry[path_key] <- entry
    widgets_mark_seen(widget_ident, path_key)
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

def private widget_meta_jv(path_key : string; meta : WidgetMeta) : JsonValue? {
    //! Snapshot blob for a widget that's registered in `g_widgets` but did
    //! NOT render this frame — no per-frame entry to join. State payload
    //! comes from the meta's serializer; bbox/hover/active/focus are
    //! absent. `rendered: false` lets clients distinguish "in the source
    //! but currently hidden" from "doesn't exist".
    var tab : table<string; JsonValue?>
    tab |> insert("kind", JV(meta.kind))
    tab |> insert("rendered", JV(false))
    tab |> insert("payload", invoke(meta.serializer))
    return JV(tab)
}

[live_command(description = "Snapshot of all registered widgets, with per-frame state joined when rendered")]
def imgui_snapshot(input : JsonValue?) : JsonValue? {
    var globals : table<string; JsonValue?>
    // Walk long-lived registry first — covers unrendered widgets too.
    for (k, meta in keys(g_widgets), values(g_widgets)) {
        if (key_exists(g_registry, k)) {
            globals |> insert(k, widget_entry_jv(k, g_registry[k]))
        } else {
            globals |> insert(k, widget_meta_jv(k, meta))
        }
    }
    // Fold in any per-frame entry not in g_widgets — e.g. containers
    // (which still write g_registry but don't go through register_widget
    // yet). Keeps existing 0b behavior intact while the macro is migrated.
    for (k, v in keys(g_registry), values(g_registry)) {
        if (!key_exists(g_widgets, k)) {
            globals |> insert(k, widget_entry_jv(k, v))
        }
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
