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
require daslib/coroutines public
require daslib/async_boost
require daslib/result public
require math
require strings

// See handmade/module-imgui_boost_runtime.rst for the runtime overview.

// ===== Per-kind state structs =====
//
// Mixed @live (preserved across hot-reload) and @optional (transient,
// dropped from JV when zero-valued). Common per-frame imgui state — hex_id,
// bbox, hover/active/focus — lives in WidgetEntry, not here, so the structs
// stay small per kind.

struct ClickState {
    @live click_count : int                      //! cumulative across reloads
    @optional pending_click : bool               //! queued by imgui_click L2; consumed next frame
    @optional clicked : bool                     //! true on the frame the button fired
}

struct SliderStateFloat {
    @live value : float                          //! preserved across reload
    @live bounds : tuple<float; float>           //! (min, max)
    @optional has_pending : bool                 //! imgui_set L3 sets; render fn consumes
    @optional pending_value : float              //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct SliderStateFloat2 {
    @live value : float2                         //! preserved across reload
    @live bounds : tuple<float; float>           //! (min, max) applied to every component
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float2             //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct SliderStateFloat3 {
    @live value : float3                         //! preserved across reload
    @live bounds : tuple<float; float>           //! (min, max) applied to every component
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float3             //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct SliderStateFloat4 {
    @live value : float4                         //! preserved across reload
    @live bounds : tuple<float; float>           //! (min, max) applied to every component
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float4             //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct SliderStateInt {
    @live value : int                            //! preserved across reload
    @live bounds : tuple<int; int>               //! (min, max)
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int                //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct SliderStateInt2 {
    @live value : int2                           //! preserved across reload
    @live bounds : tuple<int; int>               //! (min, max) applied to every component
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int2               //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct SliderStateInt3 {
    @live value : int3                           //! preserved across reload
    @live bounds : tuple<int; int>               //! (min, max) applied to every component
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int3               //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct SliderStateInt4 {
    @live value : int4                           //! preserved across reload
    @live bounds : tuple<int; int>               //! (min, max) applied to every component
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int4               //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct ToggleState {
    //! Shared across Checkbox / RadioButton (bool form) / Selectable / MenuItem.
    //! `pending_toggle` + `pending_value` let imgui_set steer the next frame's
    //! value deterministically; the renderer consumes-then-clears.
    @live value : bool                               //! current toggle state; preserved across reload
    @optional pending_toggle : bool                  //! imgui_set L3 sets; consumed next frame
    @optional pending_value : bool                   //! next-frame value queued by imgui_set
    @optional changed : bool                         //! true on the frame the widget fired
}

struct RadioIntState {
    //! Backs RadioButton(int form). `value` is the currently-selected button
    //! id; the widget def takes the per-call `v_button` and writes value=v_button
    //! when the user clicks. `imgui_set {"value":N}` steers the selection.
    @live value : int                                //! currently-selected button id
    @optional pending_set : bool                     //! imgui_set queued; consumed next frame
    @optional pending_value : int                    //! next-frame selection queued by imgui_set
    @optional changed : bool                         //! true on the frame the selection changed
}

// Drag* family. One state struct per scalar-or-vector value type the imgui
// API exposes; `bounds` is the only persistent config (zero-init = unclamped
// per ImGui's v_min==v_max semantics). `speed`, `format`, `flags` are passed
// at the call site — globals can't apply struct field defaults (they're
// zero-init), and string defaults trip the uninit-safety check. `pending_value`
// matches `value`'s type so the generic `drag_set_finalize` helper in
// imgui_widgets_builtin can capture state and steer it from imgui_set.

struct DragStateFloat {
    @live value : float                          //! preserved across reload
    @live bounds : tuple<float; float>           //! (min, max); zero-init = unclamped
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float              //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct DragStateFloat2 {
    @live value : float2                         //! preserved across reload
    @live bounds : tuple<float; float>           //! (min, max); zero-init = unclamped
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float2             //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct DragStateFloat3 {
    @live value : float3                         //! preserved across reload
    @live bounds : tuple<float; float>           //! (min, max); zero-init = unclamped
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float3             //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct DragStateFloat4 {
    @live value : float4                         //! preserved across reload
    @live bounds : tuple<float; float>           //! (min, max); zero-init = unclamped
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float4             //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct DragStateInt {
    @live value : int                            //! preserved across reload
    @live bounds : tuple<int; int>               //! (min, max); zero-init = unclamped
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int                //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct DragStateInt2 {
    @live value : int2                           //! preserved across reload
    @live bounds : tuple<int; int>               //! (min, max); zero-init = unclamped
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int2               //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct DragStateInt3 {
    @live value : int3                           //! preserved across reload
    @live bounds : tuple<int; int>               //! (min, max); zero-init = unclamped
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int3               //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct DragStateInt4 {
    @live value : int4                           //! preserved across reload
    @live bounds : tuple<int; int>               //! (min, max); zero-init = unclamped
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int4               //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct DragStateRangeFloat {
    //! `value.x` = current_min, `value.y` = current_max. Bounds clamp both.
    //! `imgui_set {"value":[lo,hi]}` writes the whole range atomically.
    @live value : float2                         //! (current_min, current_max); preserved across reload
    @live bounds : tuple<float; float>           //! (min, max) clamp applied to both endpoints
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float2             //! next-frame range queued by imgui_set
    @optional changed : bool                     //! true on the frame the range changed
}

struct DragStateRangeInt {
    //! `value.x` = current_min, `value.y` = current_max.
    @live value : int2                           //! (current_min, current_max); preserved across reload
    @live bounds : tuple<int; int>               //! (min, max) clamp applied to both endpoints
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int2               //! next-frame range queued by imgui_set
    @optional changed : bool                     //! true on the frame the range changed
}

// Input* numeric family. No bounds — InputFloat/Int/Double don't clamp;
// step / step_fast / format are per-call args (uniform with Drag/Slider).
// Only `value` persists. Same has_pending/pending_value/changed shape so
// `pending_value_finalize` covers the dispatch.

struct InputStateFloat {
    @live value : float                          //! preserved across reload
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float              //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct InputStateFloat2 {
    @live value : float2                         //! preserved across reload
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float2             //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct InputStateFloat3 {
    @live value : float3                         //! preserved across reload
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float3             //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct InputStateFloat4 {
    @live value : float4                         //! preserved across reload
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float4             //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct InputStateInt {
    @live value : int                            //! preserved across reload
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int                //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct InputStateInt2 {
    @live value : int2                           //! preserved across reload
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int2               //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct InputStateInt3 {
    @live value : int3                           //! preserved across reload
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int3               //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct InputStateInt4 {
    @live value : int4                           //! preserved across reload
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int4               //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

struct InputStateDouble {
    @live value : double                         //! preserved across reload
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : double             //! next-frame value queued by imgui_set
    @optional changed : bool                     //! true on the frame the widget fired
}

// Color* family. ColorEdit3/ColorPicker3 share ColorState3 (RGB);
// ColorEdit4/ColorPicker4 share ColorState4 (RGBA). ColorButton is
// click-only (no value stored — caller passes the color per-frame),
// so it reuses ClickState (mirrors `button` / `small_button`). `flags`
// is per-call; ImGui's color flags (DisplayHSV, Float, NoInputs, …)
// are call-site config, not persistent state.

struct ColorState3 {
    @live value : float3                         //! RGB in [0..1]
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float3             //! next-frame RGB queued by imgui_set
    @optional changed : bool                     //! true on the frame the color changed
}

struct ColorState4 {
    @live value : float4                         //! RGBA in [0..1]
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : float4             //! next-frame RGBA queued by imgui_set
    @optional changed : bool                     //! true on the frame the color changed
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
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int                //! next-frame selection queued by imgui_set
    @optional changed : bool                     //! true on the frame the selection changed
    @optional items_buf : array<uint8>           //! transient zero-separated buffer; rebuilt each frame
}

struct ListBoxState {
    @live value : int = -1                       //! selected index, -1 = none
    @optional has_pending : bool                 //! imgui_set queued; consumed next frame
    @optional pending_value : int                //! next-frame selection queued by imgui_set
    @optional changed : bool                     //! true on the frame the selection changed
}

// Text-input family. The buffer is the canonical storage; `value` is the
// extracted (clone-on-change) string presented to user code.
// `input_text_growable` reuses this struct; its CallbackResize lambda
// updates `capacity` + `buffer` in place.

struct InputTextState {
    @live value : string = ""                             //! current text content (clone of buffer)
    @live capacity : int = 256                            //! working buffer size in bytes (incl. trailing null)
    @optional has_pending : bool                          //! imgui_set queued; consumed next frame
    @optional pending_value : string = ""                 //! next-frame text queued by imgui_set
    @optional changed : bool                              //! true on the frame the text changed
    @optional buffer : array<uint8>                       //! working buffer; mirrors `value`, allocated to capacity on first frame / post-reload
}

struct TextShowState {
    //! Backs the `text_show` display widget (master plan §4.3a). Read-only
    //! from the user's perspective — `value` is set either by an
    //! initializer at the call site (`text_show(STATUS, value="saved")`)
    //! or programmatically (`STATUS.value = compute_status()`). The
    //! standard serializer surfaces `value` for telemetry / playwright
    //! `expect_value(app, STATUS, "saved")`. Tests can also drive the
    //! value externally via `imgui_set` — the dispatcher writes
    //! `state.value` directly.
    @live value : string = ""                          //! displayed text; settable via call-site initializer or imgui_set
}

struct PlotState {
    //! Backs the `plot_lines` / `plot_histogram` display widgets. The
    //! plotted values are passed per-frame as a parameter (not stored in
    //! state) — same shape as the imgui_test_engine and daslib v1
    //! conventions. State carries last-frame's call args for telemetry:
    //! the visible label, the (scale_min, scale_max) range, and the
    //! sample count. Read-only — no dispatcher.
    @optional title : string                           //! overlay text
    @optional bounds : tuple<float; float>             //! (scale_min, scale_max)
    @optional samples : int                            //! length(values) last frame
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
    //! frame observed (pos/size/collapsed/scroll) or echoed from per-call
    //! args (flags). ImGui persists window pos itself via imgui.ini, so
    //! duplicating it as `@live` would only fight that. `imgui_open` /
    //! `imgui_close` flow through pending_open/close; the renderer applies
    //! them at the top of the next frame. Per-call config (closable, flags)
    //! is supplied via the named-tuple at the call site — same convention
    //! as `[widget]`.
    @live open : bool = true                  //! window open state; preserved across reload
    @optional flags : ImGuiWindowFlags        //! per-call ImGuiWindowFlags (echoed for telemetry)
    @optional pos : float2                    //! observed window position (top-left, screen coords)
    @optional size : float2                   //! observed window size
    @optional collapsed : bool                //! observed collapsed state
    @optional scroll : float2                 //! (GetScrollX, GetScrollY) of the window
    @optional scroll_max : float2             //! (GetScrollMaxX, GetScrollMaxY)
    @optional pending_open : bool             //! imgui_open queued; applied next frame
    @optional pending_close : bool            //! imgui_close queued; applied next frame
}

struct ChildState {
    //! Backs the `child` container. All fields are observed (scroll); per-
    //! call config (size, child_flags, window_flags) is supplied via the
    //! named-tuple at the call site.
    @optional size : float2                   //! per-call child region size (echoed for telemetry)
    @optional child_flags : ImGuiChildFlags   //! per-call ImGuiChildFlags
    @optional window_flags : ImGuiWindowFlags //! per-call ImGuiWindowFlags
    @optional scroll : float2                 //! (GetScrollX, GetScrollY)
    @optional scroll_max : float2             //! (GetScrollMaxX, GetScrollMaxY)
}

struct GroupState {
    //! Backs the `group` container. Pure layout grouping — no persistent or
    //! observable state, but the [container] macro still needs a struct to
    //! hang the auto-emitted global on. The `_placeholder` field stays
    //! @optional so JV(state) emits `{}` when the group is rendered.
    @optional _placeholder : bool             //! unused; keeps the struct non-empty for [container] auto-emit
}

struct MenuBarState {
    //! Backs the `menu_bar` container. Stateless wrapper.
    @optional _placeholder : bool             //! unused; keeps the struct non-empty for [container] auto-emit
}

struct MenuState {
    //! Backs the `menu` container — a single drop-down inside a menu bar.
    //! `enabled` is per-call; `opened` is per-frame observed.
    @optional enabled : bool                  //! per-call enable flag (echoed for telemetry)
    @optional opened : bool                   //! observed per-frame: menu is currently expanded
}

struct PopupState {
    //! Shared by `popup` and `popup_modal`. `open` is @live so the user-driven
    //! state survives reload. `imgui_open` / `imgui_close` route through
    //! pending_open/close; the renderer issues OpenPopup/CloseCurrentPopup
    //! on the next frame in response.
    @live open : bool                         //! popup open state; preserved across reload
    @optional flags : ImGuiWindowFlags        //! per-call ImGuiWindowFlags
    @optional pending_open : bool             //! imgui_open queued; OpenPopup fires next frame
    @optional pending_close : bool            //! imgui_close queued; CloseCurrentPopup fires next frame
}

struct TabBarState {
    //! Backs the `tab_bar` container. ImGui drives active-tab selection
    //! itself; we just observe.
    @optional flags : ImGuiTabBarFlags        //! per-call ImGuiTabBarFlags
}

struct TabItemState {
    //! Backs the `tab_item` container. `open` defaults to true so a closable
    //! tab renders from frame 1; the X-button or `imgui_close` flips it false.
    //! `@live` carries that across reload.
    @live open : bool = true                  //! tab open state; preserved across reload
    @optional flags : ImGuiTabItemFlags       //! per-call ImGuiTabItemFlags
    @optional pending_open : bool             //! imgui_open queued; applied next frame
    @optional pending_close : bool            //! imgui_close queued; applied next frame
}

struct TooltipState {
    //! Backs both `tooltip` and `item_tooltip`. Tooltips don't persist —
    //! they're a per-frame chrome pop.
    @optional _placeholder : bool             //! unused; keeps the struct non-empty for [container] auto-emit
}

struct TreeNodeState {
    //! Backs the `tree_node` container. ImGui owns the open/close state
    //! internally; we mirror what's observable so snapshots reflect truth,
    //! and the dispatcher routes open/close through SetNextItemOpen.
    @optional flags : ImGuiTreeNodeFlags      //! per-call ImGuiTreeNodeFlags
    @optional opened : bool                   //! observed per-frame: TreeNode returned true
    @optional pending_open : bool             //! imgui_open queued; SetNextItemOpen(true) fires next frame
    @optional pending_close : bool            //! imgui_close queued; SetNextItemOpen(false) fires next frame
}

struct CollapsingHeaderState {
    //! Backs the `collapsing_header` container. Same shape as TreeNodeState
    //! since the imgui call structurally mirrors it (returns bool, no End()).
    @optional flags : ImGuiTreeNodeFlags      //! per-call ImGuiTreeNodeFlags
    @optional opened : bool                   //! observed per-frame: CollapsingHeader returned true
    @optional pending_open : bool             //! imgui_open queued; SetNextItemOpen(true) fires next frame
    @optional pending_close : bool            //! imgui_close queued; SetNextItemOpen(false) fires next frame
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
    //! and pasted into `payload` at imgui_snapshot time. The lambda lives
    //! outside the entry because `g_registry` is cleared every frame and
    //! we need the serializer (which captures `& state` of the per-widget
    //! global) to survive that clear.
    kind : string                                //! widget kind ("button", "slider_float", ...)
    hex_id : uint                                //! ImGui's GetID() for this widget on this frame
    bbox : float4                                //! packed [x0, y0, x1, y1]
    @optional hover : bool                       //! IsItemHovered() this frame
    @optional active : bool                      //! IsItemActive() this frame
    @optional focus : bool                       //! IsItemFocused() this frame
    @optional payload : JsonValue?               //! populated by widget_entry_jv from g_serializers
}

def private widget_entry_jv(ident : string; var entry : WidgetEntry) : JsonValue? {
    if (key_exists(g_serializers, ident)) {
        entry.payload = invoke(g_serializers[ident])
    }
    return JV(entry)
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
    module_name : string                         //! owning module; lets clear_module_widgets drop on reload
    kind : string                                //! widget kind ("button", "slider_float", ...)
    state_addr : void?                           //! address of the per-widget state global (untyped)
    serializer : lambda<() : JsonValue?>         //! captured-state serializer; invoked at imgui_snapshot time
    last_seen_frame : int                        //! last g_frame this path appeared in g_registry; -1 = never rendered
}

var g_widgets : table<string; WidgetMeta>

// ===== Phase 2 reverse maps + coroutine runner =====
//
// `g_id_to_path` is a long-lived hex_id → path_key map populated by every
// widget_finalize / container_finalize. Lets `io_jv()` resolve `GetActiveID()`
// (an opaque ImGuiID) back to the user's identifier path. Surviving across
// frames mirrors `g_widgets`; cleared on hot-reload via clear_module_widgets.
//
// `g_id_to_bbox` is a per-frame hex_id → bbox map for L1 click/drag fallback
// when the target string is "0x..." but not in g_id_to_path. Cleared at the
// top of begin_frame() alongside g_registry.
//
// `g_coroutines` holds in-flight L1 input coroutines (imgui_drag, imgui_type_text).
// Each [async] command spawns one Coroutine (iterator<bool>); the runtime
// advances the array one step per frame in begin_frame() via advance_coroutines.

var private g_id_to_path : table<uint; string>
var private g_id_to_bbox : table<uint; float4>
var private g_coroutines : array<Coroutine>
var private g_focusable : table<string>     //! set: paths whose widgets accept keyboard focus
var private g_pending_focus : table<string> //! set: paths to focus on their next widget_prelude

def public id_to_path(hid : uint) : string {
    //! Resolve a raw ImGui ``hex_id`` to its boost path_key, or ``""`` when unmapped.
    return key_exists(g_id_to_path, hid) ? g_id_to_path[hid] : ""
}

def public id_to_bbox(hid : uint) : float4 {
    //! Per-frame ``hex_id`` → bbox lookup; returns ``float4(0)`` when the id didn't render this frame.
    return key_exists(g_id_to_bbox, hid) ? g_id_to_bbox[hid] : float4(0.0f, 0.0f, 0.0f, 0.0f)
}

// Deferred (Phase 4 / on-demand): a separate `extras` channel for
// transient per-frame data that doesn't belong in the persistent state
// struct (text-input cursor / selection, tooltip content). Phase 1.2
// initially planned a `lambda<() : JsonValue?> extras` field on
// WidgetMeta — dropped after a clean-room read of imgui_test_engine
// confirmed cursor/selection isn't worth public-API gymnastics (test
// engine reads InputText via clipboard, never exposes cursor/selection).
// All current "transient observed state" fits inline in the kind's state
// struct (ChildState.scroll / WindowState.collapsed / TreeNodeState.opened).
// Reintroduce the extras channel only when a real consumer (e.g. Phase 4
// visual aids) needs data that doesn't fit a state-struct field.

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
    //! Append ``widget_ident`` to the open-container chain; emitted by the ``[container]`` macro prelude.
    g_container_path |> push(widget_ident)
    if (length(g_container_path) == 1) {
        g_container_path_str = widget_ident
    } else {
        g_container_path_str = "{g_container_path_str}/{widget_ident}"
    }
}

def public container_path_pop() {
    //! Pop the tail container ident off the open-container chain; idempotent on empty.
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
    //! Build a leaf widget's registry key: open container chain (``"/"``-joined) + ``widget_ident``; bare ident when unnested.
    return widget_ident if (empty(g_container_path_str))
    return "{g_container_path_str}/{widget_ident}"
}

def public container_path_key() : string {
    //! Registry/dispatcher key for the currently-open container's own entry.
    return g_container_path_str
}

def begin_frame() {
    //! Per-frame reset: bumps the frame counter and clears the per-frame registry, ``hex_id``\ →bbox map, and container path.
    //! Call before rendering widgets; L1 coroutines advance separately via :ref:`advance_coroutines <function-imgui_boost_runtime_advance_coroutines>`.
    g_frame++
    g_registry |> clear()
    g_id_to_bbox |> clear()
    g_rendered_this_frame |> clear()
    if (!empty(g_container_path)) {
        g_container_path |> clear()
        g_container_path_str = ""
    }
}

var private g_end_of_frame_hooks : table<string; function<() : void>>

def public register_end_of_frame_hook(name : string; hook : function<() : void>) {
    //! Register a per-frame painter fired by :ref:`end_of_frame <function-imgui_boost_runtime_end_of_frame>`; re-registering the same ``name`` replaces, so live-reload doesn't multiply hooks.
    g_end_of_frame_hooks[name] = hook
}

def end_of_frame() {
    //! Per-frame painter drain — invokes every hook registered via :ref:`register_end_of_frame_hook <function-imgui_boost_runtime_register_end_of_frame_hook_string_function_ls__c_void_gr_>`. Call after rendering all widgets.
    for (h in values(g_end_of_frame_hooks)) {
        invoke(h)
    }
}

var private g_post_command_hooks : table<string; function<(command : string; target : string) : void>>

def public register_post_command_hook(name : string; hook : function<(command : string; target : string) : void>) {
    //! Register a hook fired after every successful ``imgui_*`` command with ``(command_name, resolved_target)``; same name-keyed idempotent semantics as :ref:`register_end_of_frame_hook <function-imgui_boost_runtime_register_end_of_frame_hook_string_function_ls__c_void_gr_>`.
    g_post_command_hooks[name] = hook
}

def private dispatch_post_command_hooks(command : string; target : string) {
    for (h in values(g_post_command_hooks)) {
        invoke(h, command, target)
    }
}

def public advance_coroutines() {
    //! Step every active L1 input coroutine one frame; finished coroutines drop out.
    //! Must run between ``ImGui_ImplGlfw_NewFrame()`` and ``NewFrame()`` so synthetic events aren't clobbered by the GLFW backend.
    var i = length(g_coroutines)
    while (i > 0) {
        i--
        var t : bool
        next(g_coroutines[i], t)
        if (empty(g_coroutines[i])) {
            delete g_coroutines[i]
            g_coroutines |> erase(i)
        }
    }
}

def public spawn_coroutine(var c : Coroutine) {
    //! Schedule an L1 input coroutine (one event per frame); :ref:`advance_coroutines <function-imgui_boost_runtime_advance_coroutines>` drains it.
    g_coroutines |> emplace(c)
}

// ===== Render helpers =====
//
// `widget_prelude` runs at the top of every macro-wrapped widget body
// (PushID for unique imgui scoping). `widget_finalize` runs at the bottom
// — captures the common per-frame fields, registers the lazy serializer
// + dispatcher on the first render of each ident, and balances the PushID.

def public widget_prelude(widget_ident : string) {
    //! Top-of-body helper for ``[widget]`` macros: ``PushID(widget_ident)`` and apply any pending :ref:`imgui_focus <function-imgui_boost_runtime_imgui_focus_JsonValue_q_>` request.
    PushID(widget_ident)
    if (!empty(g_pending_focus)) {
        let path_key = widget_path_key(widget_ident)
        if (key_exists(g_pending_focus, path_key)) {
            SetKeyboardFocusHere(0)
            g_pending_focus |> erase(path_key)
        }
    }
}

def public register_focusable(widget_ident : string) {
    //! Tag this widget's path as accepting keyboard focus; called from interactive finalize helpers so :ref:`imgui_focus <function-imgui_boost_runtime_imgui_focus_JsonValue_q_>` accepts the target.
    g_focusable |> insert(widget_path_key(widget_ident))
}

def public pending_value_container_finalize(widget_ident : string; kind : string;
                                             var state : auto) {
    //! Container-side install of the ``pending_value`` dispatcher (``imgui_set``); used by layout containers like ``split_h`` / ``dock_left``.
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
        container_finalize(widget_ident, kind, entry, ser, disp)
    }
}

def public pending_value_finalize(widget_ident : string; kind : string; var state : auto) {
    //! Generic serializer + ``imgui_set`` dispatcher install for any state struct with ``has_pending``/``pending_value``/``changed``; covers Drag/Slider/Input-numeric/Color/Combo/ListBox.
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
    register_focusable(widget_ident)
}

def public clear_module_widgets(module_name : string) {
    //! Drop every widget tagged with this module from the long-lived registries (g_widgets / id_to_path / focusable / pending_focus); called from each module's ``[init]`` so hot-reload re-binds cleanly.
    var paths_to_remove : array<string>
    for (k, m in keys(g_widgets), values(g_widgets)) {
        if (m.module_name == module_name) {
            paths_to_remove |> push(k)
        }
    }
    for (k in paths_to_remove) {
        g_widgets |> erase(k)
    }
    var ids_to_remove : array<uint>
    for (id, pk in keys(g_id_to_path), values(g_id_to_path)) {
        for (dead in paths_to_remove) {
            if (pk == dead) {
                ids_to_remove |> push(id)
                break
            }
        }
    }
    for (id in ids_to_remove) {
        g_id_to_path |> erase(id)
    }
    for (dead in paths_to_remove) {
        g_focusable |> erase(dead)
        g_pending_focus |> erase(dead)
    }
}

def public widget_registered(path : string) : bool {
    //! Idempotency probe used by indexed-form wrappers — true when ``path`` is already in ``g_widgets``.
    return key_exists(g_widgets, path)
}

def public register_widget(module_name : string;
                           bare_ident : string;
                           kind : string;
                           state_addr : void?;
                           var serializer : lambda<() : JsonValue?>) {
    //! Module-init registration of a widget into the long-lived ``g_widgets`` table; ``module_name`` lets :ref:`clear_module_widgets <function-imgui_boost_runtime_clear_module_widgets_string>` drop it on reload.
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

// Per-frame "this path rendered already" set. Each path_key may be
// finalized exactly once between begin_frame()/end_of_frame() — collision
// means a single-global widget got rendered twice in the same frame
// (lexical duplicate, or invisibly aliased through two distinct call
// sites). Cleared at begin_frame(); checked at widget_finalize /
// container_finalize entry. Per API_REWORK §4.4: "loud, not a warning —
// telemetry needs an unambiguous path → widget mapping or test commands
// can't locate the right widget."
var private g_rendered_this_frame : table<string>

def private check_unique_render(path_key : string; kind : string) {
    // radio_button_int intentionally shares state across N per-frame calls; other kinds panic on duplicate render.
    return if (kind == "radio_button_int")
    if (key_exists(g_rendered_this_frame, path_key)) {
        let msg = "dasImgui: widget '{path_key}' ({kind}) rendered twice in frame {g_frame}. Single-global widgets must render exactly once per frame. For multiple instances, declare a table  variable private <NAME> : table<int; <STATE_TYPE>>  and call with subscript:  {kind}(<NAME>[i], (...))"
        panic(msg)
    }
    g_rendered_this_frame |> insert(path_key)
}

def public widget_finalize(widget_ident : string;
                           kind : string;
                           var entry : WidgetEntry;
                           var serializer : lambda<() : JsonValue?>;
                           var dispatcher : lambda<(action : string; payload : JsonValue?) : void>) {
    //! Bottom-of-body helper for ``[widget]`` macros: capture bbox/hover/active/focus, install the per-widget serializer + dispatcher, and ``PopID``.
    let path_key = widget_path_key(widget_ident)
    check_unique_render(path_key, kind)
    entry.kind = kind
    entry.hex_id = GetID(widget_ident)
    let rmin = GetItemRectMin()
    let rmax = GetItemRectMax()
    entry.bbox = float4(rmin.x, rmin.y, rmax.x, rmax.y)
    entry.hover = IsItemHovered(ImGuiHoveredFlags.None)
    entry.active = IsItemActive()
    entry.focus = IsItemFocused()
    g_id_to_path[entry.hex_id] = path_key
    g_id_to_bbox[entry.hex_id] = entry.bbox
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
    // First render: migrate the bare-ident entry to its container-aware path_key. Subsequent renders just bump last_seen_frame.
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
    //! Container counterpart of :ref:`widget_finalize <function-imgui_boost_runtime_widget_finalize_string_string_WidgetEntry_lambda_ls__c_void_gr__lambda_ls_action_c_string;payload_c_JsonValue_q__c_void_gr_>`; install the per-container serializer + dispatcher at the cached container path key.
    let path_key = container_path_key()
    check_unique_render(path_key, kind)
    entry.kind = kind
    entry.hex_id = GetID(widget_ident)
    g_id_to_path[entry.hex_id] = path_key
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

// ===== Phase 2 — Result wire format + per-command await =====
//
// Every [live_command] handler returns a Result<T, string> (rendered to JSON
// via the JV overload below). `with_await` is the generic wrapper that auto-
// converts any payload to JSON and threads per-command await modifiers
// (await_frames / await_until / timeout_sec / fire_and_forget) into the
// response so the transport-side await_imgui (widgets/imgui_transport) can
// poll for quiescence after dispatch. Server never blocks — running on the
// GLFW main thread inside tick() means a server-side wait deadlocks the
// frame loop that drives quiescence.

def public JV(r : $Result < auto(TT); auto(EE) >) : JsonValue? {
    //! Wire format for ``Result<T, E>``: ``{"ok": bool, "value"|"error": ...}``; the transport contract every ``imgui_*`` handler returns.
    var tab : table<string; JsonValue?>
    tab |> insert("ok", JV(r |> is_ok))
    if (r |> is_ok) {
        tab |> insert("value", JV(r._value))
    } else {
        tab |> insert("error", JV(r._error))
    }
    return JV(tab)
}

struct AwaitModifiers {
    //! Per-command await knobs. Pulled from `input["await"]` by `with_await`;
    //! all fields optional with sensible defaults (5s, no-op).
    @optional await_frames : int = -1            //! min frames to advance before considering the command settled; -1 = no frame floor
    @optional await_until : string = ""          //! quiescence predicate name (empty = default is_quiescent())
    @optional timeout_sec : float = 5.0f         //! client-side wait ceiling (seconds)
    @optional fire_and_forget : bool = false     //! when true, client skips the await loop entirely
}

def private with_await(input : JsonValue?; payload : auto(P)) : JsonValue? {
    let mods = from_JV(input?["await"], default<AwaitModifiers>)
    var jv = JV(payload)
    if (mods.fire_and_forget) return jv
    var tab : table<string; JsonValue?>
    if (jv != null && (jv.value is _object)) {
        for (k, v in keys(jv.value as _object), values(jv.value as _object)) {
            tab[k] = v
        }
    }
    if (mods.await_frames >= 0) {
        tab["await_frames"] = JV(mods.await_frames)
    }
    if (!empty(mods.await_until)) {
        tab["await_until"] = JV(mods.await_until)
    }
    tab["timeout_sec"] = JV(mods.timeout_sec)
    return JV(tab)
}

// ===== [live_command] handlers =====

def private extract_string_field(obj : JsonValue?; name : string) : string {
    let v = obj?[name]
    if (v == null || !(v.value is _string)) return ""
    return string(v.value as _string)
}

def private widget_meta_jv(path_key : string; meta : WidgetMeta) : JsonValue? {
    // Snapshot blob for a widget registered but not rendered this frame: rendered=false, state payload only.
    return JV((kind = meta.kind, rendered = false, payload = invoke(meta.serializer)))
}

def private io_jv() : JsonValue? {
    let pos = GetMousePos()
    var tab : table<string; JsonValue?>
    tab |> insert("mouse_pos", JV(float2(pos.x, pos.y)))
    tab |> insert("mouse_buttons", JV(IsMouseDown(ImGuiMouseButton.Left),
                                      IsMouseDown(ImGuiMouseButton.Middle),
                                      IsMouseDown(ImGuiMouseButton.Right)))
    tab |> insert("key_ctrl",  JV(IsKeyDown(ImGuiKey.ImGuiMod_Ctrl)))
    tab |> insert("key_shift", JV(IsKeyDown(ImGuiKey.ImGuiMod_Shift)))
    tab |> insert("key_alt",   JV(IsKeyDown(ImGuiKey.ImGuiMod_Alt)))
    tab |> insert("key_super", JV(IsKeyDown(ImGuiKey.ImGuiMod_Super)))
    let active_id = GetActiveID()
    if (active_id != 0u) {
        tab |> insert("active_id", JV(active_id))
        if (key_exists(g_id_to_path, active_id)) {
            tab |> insert("active_widget", JV(g_id_to_path[active_id]))
        }
    }
    return JV(tab)
}

[live_command(description = "Snapshot of all registered widgets, with per-frame state joined when rendered")]
def imgui_snapshot(input : JsonValue?) : JsonValue? {
    //! Live-command: return ``{frame, globals, io}`` — every registered widget joined with its per-frame entry when rendered.
    var globals : table<string; JsonValue?>
    // Walk long-lived registry first — covers unrendered widgets too.
    // EXCEPT: indexed-form entries (path contains '[') expire after one
    // frame absent. A user-table key that got removed must vanish from
    // telemetry; otherwise stale state serializers fire on slots that
    // may have been reused, returning misleading values.
    for (k, meta in keys(g_widgets), values(g_widgets)) {
        if (key_exists(g_registry, k)) {
            globals |> insert(k, widget_entry_jv(k, g_registry[k]))
        } else {
            continue if (find(k, "[") >= 0 && meta.last_seen_frame < g_frame - 1)
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
    return JV({"frame" => JV(g_frame), "globals" => JV(globals), "io" => io_jv()})
}

def private classify_target(target : string) : tuple<int; string> {
    // Map target → (level, resolved). 2 = L2 path, 1 = L1 hex_id (click-only via bbox synthesis), 0 = unresolvable.
    if (empty(target)) return (0, "")
    let n = length(target)
    let is_hex = n > 2 && slice(target, 0, 2) == "0x" || n > 2 && slice(target, 0, 2) == "0X"
    if (is_hex) {
        let hid = parse_hex_id(target)
        if (hid == 0u) return (0, target)
        if (key_exists(g_id_to_path, hid)) return (2, g_id_to_path[hid])
        return (1, target)
    }
    if (key_exists(g_dispatchers, target)) return (2, target)
    return (0, target)
}

[async]
def private click_at_coro(center : float2; button : int) : void {
    var io & = unsafe(GetIO())
    io |> AddMousePosEvent(center.x, center.y)
    io |> AddMouseButtonEvent(button, true)
    await_next_frame()
    io |> AddMouseButtonEvent(button, false)
}

def private dispatch_or_err(action : string; input : JsonValue?) : Result<string, string> {
    let target = extract_string_field(input, "target")
    let (level, resolved) = classify_target(target)
    if (level == 0) return err("unresolvable target: {target}", type<string>)
    if (level == 2) {
        if (action == "focus") {
            if (!key_exists(g_focusable, resolved)) return err("target {resolved} is not focusable (display-only widget)", type<string>)
            g_pending_focus |> insert(resolved)
            return ok(resolved, type<string>)
        }
        invoke(g_dispatchers[resolved], action, input)
        return ok(resolved, type<string>)
    }
    if (action != "click") return err("L1 hex_id fallback only supports 'click', got '{action}'", type<string>)
    let hid = parse_hex_id(resolved)
    if (!key_exists(g_id_to_bbox, hid)) return err("hex_id {resolved} not seen this frame (no bbox to click)", type<string>)
    let bb = g_id_to_bbox[hid]
    let center = float2((bb.x + bb.z) * 0.5f, (bb.y + bb.w) * 0.5f)
    spawn_coroutine(click_at_coro(center, 0))
    return ok("L1:{resolved}", type<string>)
}

[live_command(description = "Queue an L2 click on a widget identified by 'target'")]
def imgui_click(input : JsonValue?) : JsonValue? {
    //! Live-command: dispatch a ``click`` to the widget named by ``input["target"]``; resolves path or ``0x...`` hex_id.
    let r = dispatch_or_err("click", input)
    if (r._is_ok) dispatch_post_command_hooks("click", r._value)
    return with_await(input, r)
}

[live_command(description = "Queue an L3 value set on a widget ('target' name + 'value')")]
def imgui_set(input : JsonValue?) : JsonValue? {
    //! Live-command: steer the next-frame value of ``input["target"]`` to ``input["value"]``.
    let r = dispatch_or_err("set", input)
    if (r._is_ok) dispatch_post_command_hooks("set", r._value)
    return with_await(input, r)
}

[live_command(description = "Queue an open command on a container widget ('target' name)")]
def imgui_open(input : JsonValue?) : JsonValue? {
    //! Live-command: open the container named by ``input["target"]`` (window/popup/tree_node/collapsing_header/tab_item).
    let r = dispatch_or_err("open", input)
    if (r._is_ok) dispatch_post_command_hooks("open", r._value)
    return with_await(input, r)
}

[live_command(description = "Queue a close command on a container widget ('target' name)")]
def imgui_close(input : JsonValue?) : JsonValue? {
    //! Live-command: close the container named by ``input["target"]`` (window/popup/tree_node/collapsing_header/tab_item).
    let r = dispatch_or_err("close", input)
    if (r._is_ok) dispatch_post_command_hooks("close", r._value)
    return with_await(input, r)
}

[live_command(description = "Force keyboard focus to a widget identified by 'target' (path or hex_id)")]
def imgui_focus(input : JsonValue?) : JsonValue? {
    //! Live-command: force keyboard focus onto ``input["target"]``; the widget's path must have been tagged via :ref:`register_focusable <function-imgui_boost_runtime_register_focusable_string>`.
    let r = dispatch_or_err("focus", input)
    if (r._is_ok) dispatch_post_command_hooks("focus", r._value)
    return with_await(input, r)
}

[live_command(description = "Re-dock a dock_window to a specific dock node ('target' name, 'value' = dock_id uint)")]
def imgui_dock(input : JsonValue?) : JsonValue? {
    //! Live-command: re-dock the dock_window named by ``input["target"]`` into the dock node id supplied in ``input["value"]`` (a ``uint`` from a ``DockBuilder*`` call). Routes through SetNextWindowDockID on the next frame.
    let r = dispatch_or_err("dock", input)
    if (r._is_ok) dispatch_post_command_hooks("dock", r._value)
    return with_await(input, r)
}

[live_command(description = "Pop a dock_window out of its current dock node ('target' name)")]
def imgui_undock(input : JsonValue?) : JsonValue? {
    //! Live-command: undock the dock_window named by ``input["target"]``; the window becomes free-floating. Routes through SetNextWindowDockID(0) on the next frame.
    let r = dispatch_or_err("undock", input)
    if (r._is_ok) dispatch_post_command_hooks("undock", r._value)
    return with_await(input, r)
}

[live_command(description = "Clear a dockspace's DockBuilder layout so the user's setup runs again ('target' = dockspace name)")]
def imgui_dock_reset(input : JsonValue?) : JsonValue? {
    //! Live-command: reset the dockspace named by ``input["target"]`` — clears the DockBuilder node tree and flips ``state.has_initial_layout`` back to false so the user's setup function re-runs on the next frame.
    let r = dispatch_or_err("reset", input)
    if (r._is_ok) dispatch_post_command_hooks("reset", r._value)
    return with_await(input, r)
}

[live_command(description = "Reposition a dock_window ('target' name, 'value' = JSON with x/y and optional w/h)")]
def imgui_set_window_pos(input : JsonValue?) : JsonValue? {
    //! Live-command: reposition the dock_window named by ``input["target"]``. ``value`` is a JSON object with required ``x``/``y`` and optional ``w``/``h``. Routes through SetNextWindowPos / SetNextWindowSize on the next frame; useful for placing a window after ``imgui_undock`` (the floating-window default location is implementation-defined) or for scripted layouts.
    let r = dispatch_or_err("set_window_pos", input)
    if (r._is_ok) dispatch_post_command_hooks("set_window_pos", r._value)
    return with_await(input, r)
}

// ===== Phase 2.5 — Quiescence probe =====
//
// imgui_await is a polling probe: server reports current liveness state
// (`{quiescent, frame, pending_coroutines, active_id}`) and the client
// (widgets/imgui_transport — Phase 2.6) drives the wait loop. Server-side
// blocking is incompatible with the GLFW-main-thread invariant — the
// dispatch handler runs on the same thread that advances frames.

struct AwaitArgs {
    @optional until : string = "quiescent"       //! quiescence predicate name to poll
    @optional frame : int = -1                   //! when >=0, return quiescent once g_frame >= this value
}

struct AwaitResult {
    quiescent : bool = false                     //! true when the requested condition currently holds
    frame : int = 0                              //! server's current g_frame
    pending_coroutines : int = 0                 //! length(g_coroutines) — in-flight L1 input drivers
    active_id : uint = 0u                        //! GetActiveID() — non-zero when a widget is being interacted with
}

// AwaitResult is a plain-fields struct — JV(struct) auto-walker handles
// the {quiescent, frame, pending_coroutines, active_id} shape for free.

def private is_quiescent() : bool {
    return (!IsAnyItemActive() &&
            !IsAnyMouseDown() &&
            GetActiveID() == 0u &&
            empty(g_coroutines))
}

[live_command(description = "Probe quiescence; returns AwaitResult with frame, pending_coroutines, active_id")]
def imgui_await(input : JsonValue?) : JsonValue? {
    //! Live-command: poll quiescence. Returns ``{quiescent, frame, pending_coroutines, active_id}`` — clients drive the wait loop client-side (the server runs on the GLFW thread).
    let args = from_JV(input, default<AwaitArgs>)
    var result = AwaitResult(frame = g_frame,
                             pending_coroutines = length(g_coroutines),
                             active_id = GetActiveID())
    if (args.frame >= 0) {
        result.quiescent = g_frame >= args.frame
    } else {
        result.quiescent = is_quiescent()
    }
    return with_await(input, ok(result, type<string>))
}

// ===== Phase 2.2 — L1 IO synthesis (coroutine-driven) =====
//
// drag/type_text push raw ImGuiIO events through `[async]` coroutines that
// yield one event per frame. The widget consumes them on subsequent frames
// like any other input. Targets resolve via the same path/hex_id rails the
// L2 dispatchers use. `target` for type_text is informational until Phase
// 2.4 wires the focus arm; chars go to whichever widget already holds focus.

struct DragArgs {
    @optional target : string = ""               //! widget path or 0x... hex_id where the drag starts
    @optional dx : float = 0.0f                  //! horizontal pixel delta from start to end
    @optional dy : float = 0.0f                  //! vertical pixel delta from start to end
    @optional steps : int = 4                    //! interpolation steps (one mouse move per frame)
    @optional button : int = 0                   //! ImGuiMouseButton index (0=Left, 1=Right, 2=Middle)
}

struct TypeTextArgs {
    @optional target           : string = ""     //! informational target path (chars go to whichever widget holds focus)
    @optional text             : string = ""     //! ASCII text to push one char at a time
    @optional per_char_frames  : int    = 1      //! frames between consecutive chars
    @optional total_frames     : int    = 0      //! when >0, overrides per_char_frames so the typing fits this frame budget
}

def private parse_hex_id(s : string) : uint {
    // Parse "0x..." / "0X..." → uint; 0u on failure (matches ImGui's "no widget" sentinel).
    let n = length(s)
    if (n <= 2) return 0u
    let prefix = slice(s, 0, 2)
    if (prefix != "0x" && prefix != "0X") return 0u
    return uint(to_int64(slice(s, 2), true))
}

def public widget_rect(target : string) : tuple<bool; float4> {
    //! Resolve a target string (path or ``0x...`` hex_id) to its last-known bbox ``(x0,y0,x1,y1)``; returns ``(false, float4(0))`` on miss.
    if (key_exists(g_registry, target)) return (true, g_registry[target].bbox)
    let hid = parse_hex_id(target)
    if (hid != 0u && key_exists(g_id_to_bbox, hid)) return (true, g_id_to_bbox[hid])
    return (false, float4(0.0f, 0.0f, 0.0f, 0.0f))
}

def public active_widget_path() : string {
    //! Path of the currently active/focused boost-wrapped widget, or ``""`` when none.
    let aid = GetActiveID()
    return "" if (aid == 0u)
    return id_to_path(aid)
}

def private resolve_target_bbox(target : string) : tuple<bool; float2> {
    let r = widget_rect(target)
    if (!r._0) return (false, float2(0.0f, 0.0f))
    let bb = r._1
    return (true, float2((bb.x + bb.z) * 0.5f, (bb.y + bb.w) * 0.5f))
}

[async]
def private drag_coro(start : float2; endp : float2; steps : int; button : int) : void {
    var io & = unsafe(GetIO())
    io |> AddMousePosEvent(start.x, start.y)
    io |> AddMouseButtonEvent(button, true)
    await_next_frame()
    for (i in range(1, steps + 1)) {
        let t = float(i) / float(steps)
        let p = start + (endp - start) * t
        io |> AddMousePosEvent(p.x, p.y)
        await_next_frame()
    }
    io |> AddMouseButtonEvent(button, false)
}

[async]
def private type_text_coro(text : string; per_char_frames : int) : void {
    // L1 keyboard input: one ASCII char every per_char_frames frames via AddInputCharactersUTF8. ASCII only — multi-byte sequences would split.
    var io & = unsafe(GetIO())
    let n = length(text)
    let gap = max(1, per_char_frames)
    for (i in range(n)) {
        io |> AddInputCharactersUTF8(slice(text, i, i + 1))
        for (_ in range(gap)) {
            await_next_frame()
        }
    }
}

[live_command(description = "L1 drag: synthesize mouse-press → N moves → release at target widget bbox center")]
def imgui_drag(input : JsonValue?) : JsonValue? {
    //! Live-command: spawn an L1 drag coroutine — press at ``target`` bbox center, walk ``(dx,dy)`` over ``steps`` frames, release.
    let args = from_JV(input, default<DragArgs>)
    let (found, start) = resolve_target_bbox(args.target)
    if (!found) return with_await(input, err("drag target unresolved: {args.target}", type<string>))
    let endp = start + float2(args.dx, args.dy)
    spawn_coroutine(drag_coro(start, endp, max(args.steps, 1), args.button))
    dispatch_post_command_hooks("drag", args.target)
    return with_await(input, ok(args.target, type<string>))
}

[live_command(description = "L1 keyboard: push UTF-8 chars to the focused widget. Args: text, per_char_frames (default 1) | total_frames (preferred for fixed-duration typing)")]
def imgui_type_text(input : JsonValue?) : JsonValue? {
    //! Live-command: spawn an L1 typing coroutine that pushes ``text`` to whichever widget currently holds focus.
    let args = from_JV(input, default<TypeTextArgs>)
    if (empty(args.text)) return with_await(input, err("missing 'text'", type<string>))
    var gap = max(1, args.per_char_frames)
    if (args.total_frames > 0) {
        gap = max(1, args.total_frames / length(args.text))
    }
    spawn_coroutine(type_text_coro(args.text, gap))
    if (!empty(args.target)) dispatch_post_command_hooks("type_text", args.target)
    return with_await(input, ok(args.target, type<string>))
}
