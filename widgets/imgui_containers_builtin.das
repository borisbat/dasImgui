options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options _allow_imgui_legacy = true

module imgui_containers_builtin shared

require imgui public
require imgui/imgui_boost_runtime public
require imgui/imgui_boost_v2 public
require imgui/imgui_widgets_builtin       // edit_finalize for [edit_container] rails
require daslib/json public
require daslib/json_boost
require math

//! Phase 0b.3 container widgets — block-arg wrappers around ImGui's Begin/End
//! family. Each is annotated with `[container]`, which wraps the body with
//! `container_path_push(widget_ident)` / `container_path_pop()` so leaf
//! widgets rendered inside `invoke(blk)` get hierarchical registry keys
//! ("MAIN_WIN/SETTINGS_TAB/RPS"). The Begin → invoke → End pairing rules
//! differ per kind (Begin/End and BeginChild/EndChild always-pair; everything
//! else End-only-on-true), so each def authors that pairing inline rather
//! than the macro guessing.

// ===== Common finalize helpers =====
//
// Two shapes cover the 15 containers' dispatch needs:
//
// `open_close_finalize` — for state with `pending_open` / `pending_close`
// fields (window, popup, popup_modal, tab_item, tree_node, collapsing_header).
// Routes `imgui_open` / `imgui_close` actions to the pending flags; the
// renderer consumes them at the top of the next frame.
//
// `stateless_finalize` — for containers whose dispatch surface is empty
// (group, menu_bar, menu, child, tab_bar, tooltip, item_tooltip). No
// ``[widget_dispatch]`` is registered for those state structs; on a stray
// action targeting one, ``dispatch_or_err`` silently returns ok (the
// Structure-with-no-dispatcher path is treated as display-only). The
// serializer still reflects state for snapshot.
//
// `combo_select` / `list_box` reuse ComboState / ListBoxState (a
// `pending_value : int` shape) and share the per-state-struct dispatcher
// from imgui_widgets_builtin (one ``[widget_dispatch]`` per state type
// covers every kind that uses that state).

def private open_close_finalize(widget_ident : string; kind : string; var state : auto(ST);
                                bbox : float4 = float4(0.0f, 0.0f, 0.0f, 0.0f)) {
    //! Container finalize for state with ``pending_open`` / ``pending_close``. Dispatch routes through ``g_dispatchers`` keyed by ``ST``'s ``TypeInfo.hash`` to the ``[widget_dispatch] def _(var state : ST; …)`` body below.
    var entry : WidgetEntry
    capture_item_bbox(entry, bbox)
    unsafe {
        container_finalize(widget_ident, kind, entry,
                           addr(state),
                           reinterpret<TypeInfo const?>(typeinfo rtti_typeinfo(type<ST>)))
    }
}

def public stateless_finalize(widget_ident : string; kind : string; var state : auto(ST);
                              bbox : float4 = float4(0.0f, 0.0f, 0.0f, 0.0f)) {
    //! Container finalize for stateless containers (no dispatcher actions). Snapshot rail still reflects state for telemetry; no ``[widget_dispatch]`` is registered for ``ST``, so ``g_dispatchers[(*ti).hash]`` is absent and ``dispatch_or_err`` silently returns ok if a stray action ever targets one (Structure-with-no-dispatcher = display-only).
    var entry : WidgetEntry
    capture_item_bbox(entry, bbox)
    unsafe {
        container_finalize(widget_ident, kind, entry,
                           addr(state),
                           reinterpret<TypeInfo const?>(typeinfo rtti_typeinfo(type<ST>)))
    }
}

def private current_item_bbox() : float4 {
    //! Snapshot ``GetItemRectMin/Max`` for the "last item" — meaningful for
    //! containers whose Begin* call emits a clickable header into the parent
    //! (``menu`` / ``tab_item``). Returns the captured rect in its native space; the
    //! finalizers route it through ``capture_item_bbox``, which maps it to screen (and
    //! records ``canvas_bbox``) when a snapshot item-transform is active.
    let rmin = GetItemRectMin()
    let rmax = GetItemRectMax()
    return float4(rmin.x, rmin.y, rmax.x, rmax.y)
}

// ===== Notes on ergonomics =====
//
// `[container]` defs follow the same named-tuple convention as `[widget]`:
// per-call config goes through the tuple, e.g.
//
//   window(MAIN_WIN, (text="Main", closable=false, flags=ImGuiWindowFlags.None)) <| ${body}
//
// The CallMacro destructures the named-tuple positionally (matching the
// function's parameter declaration order — see mouse card
// `dasimgui-widget-named-tuple-args-positional-not-named`). The block-as-
// last-arg sugar appends the block at the trailing slot, so the function
// signature is `(state, widget_ident, …named-tuple positional args…, blk)`.
//
// Defaults at the end DON'T work for [container] (they'd land the block in
// the wrong slot — daslang positional resolution doesn't auto-fill mid-
// position defaults to align a trailing block-arg). All per-call config args
// are required; the user passes them all in the named-tuple. The default
// values from imgui (e.g. ImGuiWindowFlags.None) are spelled out at the
// call site, mirroring how other dasImgui widgets surface flag args.

// ===== Window family =====

[container]
def window(var state : WindowState; text : string; closable : bool;
           flags : ImGuiWindowFlags; blk : block) {
    //! `Begin(name, p_open, flags)` paired with `End()` whenever Begin was
    //! called. When `closable=true` and `state.open` is false, we SKIP
    //! Begin/End entirely (the ImGui idiom — a closable window stops being
    //! drawn once the X-button or imgui_close fires; the application is
    //! expected to stop calling Begin, not continue with `*p_open=false`).
    //! `imgui_open` / `imgui_close` route through pending_open/close.
    //! `state.open` defaults to true (see WindowState) so closable windows
    //! render from frame 1.
    if (state.pending_open) {
        state.open = true
        state.pending_open = false
    }
    if (state.pending_close) {
        state.open = false
        state.pending_close = false
    }
    state.flags = flags
    if (!closable || state.open) {
        if (state.pending_size_set) {
            SetNextWindowSize(ImVec2(state.pending_size.x, state.pending_size.y), ImGuiCond.Always)
            state.pending_size_set = false
        }
        var p_open : bool? = null
        if (closable) {
            unsafe {
                p_open = addr(state.open)
            }
        }
        let im_open = Begin(text, p_open, flags)
        if (im_open) {
            let pos = GetWindowPos()
            let size = GetWindowSize()
            state.pos = float2(pos.x, pos.y)
            state.size = float2(size.x, size.y)
            state.collapsed = IsWindowCollapsed()
            state.scroll = float2(GetScrollX(), GetScrollY())
            invoke(blk)
            // scroll_max derives from the content extent — must be read
            // AFTER the body emits items, before End() pops the window.
            state.scroll_max = float2(GetScrollMaxX(), GetScrollMaxY())
        }
        End()
    }
    open_close_finalize(widget_ident, "window", state)
}

// ===== Window mutation / viewport helpers =====
//
// `SetWindowSize` mid-frame mutation (operates on the current/last window),
// the `GetCenter()` viewport method, and `IsMousePosValid` mouse query are
// thin pass-throughs — caller-driven, no widget host needed. Wrapped (not
// allow-listed) so consumer code stays free of raw `imgui::*` calls.

def public set_window_size(size : float2; cond : ImGuiCond = ImGuiCond.None) {
    //! `SetWindowSize(size, cond)` — resize the current/last window. Pair with
    //! `SetNextWindowSizeConstraints` to clamp into a fixed range.
    SetWindowSize(size, cond)
}

def public viewport_center(self : ImGuiViewport implicit) : float2 {
    //! `viewport.GetCenter()` — viewport's center-screen position. Pair with
    //! `SetNextWindowPos(center, ImGuiCond.Always, float2(0.5,0.5))` to center
    //! the next window on the viewport.
    return self |> GetCenter()
}

def public is_mouse_pos_valid() : bool {
    //! `IsMousePosValid(NULL)` — true when ImGui has a sensible mouse position
    //! (false on platforms / first frame where the mouse hasn't been observed).
    return IsMousePosValid(null)
}

[container]
def child(var state : ChildState; text : string; size : float2;
          child_flags : ImGuiChildFlags; window_flags : ImGuiWindowFlags;
          blk : block) {
    //! `BeginChild(str, size, child_flags, window_flags)` paired unconditionally
    //! with `EndChild()` per modern ImGui's "must always end" rule. Scroll
    //! position is observed when the child rendered.
    state.size = size
    state.child_flags = child_flags
    state.window_flags = window_flags
    let im_open = BeginChild(text, size, child_flags, window_flags)
    if (im_open) {
        state.scroll = float2(GetScrollX(), GetScrollY())
        invoke(blk)
        // scroll_max derives from the content extent — read AFTER invoke.
        state.scroll_max = float2(GetScrollMaxX(), GetScrollMaxY())
    }
    EndChild()
    stateless_finalize(widget_ident, "child", state)
}

def public child_scroll_reenter(widget_ident : string; text : string; blk : block) {
    //! Re-enter an existing child window (created earlier this frame by
    //! `child(IDENT, (text = ...))`) to nudge its scroll position via
    //! `SetScrollX` / `SetScrollY` inside `blk`. Replicates the original
    //! container's `PushID(IDENT)` frame (emitted by `widget_prelude`) so
    //! `BeginChild(text, ...)` hashes to the SAME window — without it ImGui
    //! creates a phantom sibling and the scroll nudge silently has no visible
    //! effect. `widget_ident` MUST be the literal IDENT string the original
    //! `child` was called with — typo = silent miss. No registry entry; this
    //! is a scroll-nudge, not a container.
    PushID(widget_ident)
    BeginChild(text, float2(0.0f, 0.0f), ImGuiChildFlags.None, ImGuiWindowFlags.None)
    invoke(blk)
    EndChild()
    PopID()
}

[container]
def group(var state : GroupState; blk : block) {
    //! `BeginGroup()` / `EndGroup()` — pure layout grouping, no return value
    //! to gate on, no per-frame state to capture.
    BeginGroup()
    invoke(blk)
    EndGroup()
    stateless_finalize(widget_ident, "group", state)
}

// ===== Menu family =====

[container]
def menu_bar(var state : MenuBarState; blk : block) {
    //! `BeginMenuBar()` / `EndMenuBar()` — only-on-true pairing. Renders the
    //! menu bar of the enclosing window (Begin must have been called with
    //! ImGuiWindowFlags.MenuBar) or a child window.
    let im_open = BeginMenuBar()
    if (im_open) {
        invoke(blk)
        EndMenuBar()
    }
    stateless_finalize(widget_ident, "menu_bar", state)
}

[container]
def main_menu_bar(var state : MainMenuBarState; blk : block) {
    //! `BeginMainMenuBar()` / `EndMainMenuBar()` — screen-top persistent menu
    //! bar; only-on-true pairing. Unlike `menu_bar` this does NOT require an
    //! enclosing `window(...)` with the MenuBar flag — call it directly at
    //! the top of the per-frame body (after NewFrame, before any window).
    let im_open = BeginMainMenuBar()
    if (im_open) {
        invoke(blk)
        EndMainMenuBar()
    }
    stateless_finalize(widget_ident, "main_menu_bar", state)
}

[container]
def menu(var state : MenuState; text : string; enabled : bool; blk : block) {
    //! `BeginMenu(label, enabled)` / `EndMenu()` — only-on-true pairing.
    //! `enabled` is a per-call knob; `state.opened` mirrors the per-frame
    //! BeginMenu return so snapshots tell whether the dropdown is showing.
    state.enabled = enabled
    let im_open = BeginMenu(text, enabled)
    state.opened = im_open
    //! Capture the menu HEADER rect right after BeginMenu — the header is the
    //! parent-strip clickable item that ``IsItem*`` resolves against. If we
    //! defer to ``stateless_finalize`` after EndMenu, the "last item" is
    //! something inside the cascade body (or popped state), which renders the
    //! bbox useless for recording drivers / playwright clicks.
    let header_bbox = current_item_bbox()
    if (im_open) {
        invoke(blk)
        EndMenu()
    }
    stateless_finalize(widget_ident, "menu", state, header_bbox)
}

// ===== Popup family =====

[container]
def popup(var state : PopupState; text : string;
          flags : ImGuiWindowFlags; blk : block) {
    //! `BeginPopup(name, flags)` / `EndPopup()` — only-on-true pairing.
    //! `imgui_open` enqueues OpenPopup(text) on the next frame; the popup
    //! then opens via ImGui's internal stack. `imgui_close` enqueues a
    //! CloseCurrentPopup inside the active popup body.
    if (state.pending_open) {
        OpenPopup(text, ImGuiPopupFlags.None)
        state.open = true
        state.pending_open = false
    }
    state.flags = flags
    let im_open = BeginPopup(text, flags)
    if (im_open) {
        if (state.pending_close) {
            CloseCurrentPopup()
            state.open = false
            state.pending_close = false
        }
        invoke(blk)
        EndPopup()
    } else {
        // ImGui closed the popup (click outside, ESC, …); reflect it.
        state.open = false
        state.pending_close = false
    }
    open_close_finalize(widget_ident, "popup", state)
}

[container]
def popup_context_item(var state : PopupContextItemState; str_id : string;
                       flags : ImGuiPopupFlags; blk : block) {
    //! `BeginPopupContextItem(str_id, flags)` / `EndPopup()` — right-click
    //! context popup attached to the previously submitted item. ImGui drives
    //! open/close internally on right-click; body runs only while open.
    let im_open = BeginPopupContextItem(str_id, flags)
    if (im_open) {
        invoke(blk)
        EndPopup()
    }
    stateless_finalize(widget_ident, "popup_context_item", state)
}

[container]
def popup_context_window(var state : PopupContextWindowState; str_id : string;
                         flags : ImGuiPopupFlags; blk : block) {
    //! `BeginPopupContextWindow(str_id, flags)` / `EndPopup()` — right-click
    //! anywhere inside the enclosing window opens a context popup. ImGui
    //! drives open/close internally; body runs only while open. `str_id`
    //! is the popup's stack id — pass a unique non-empty string per
    //! consumer (the C-level `"##ContextWindow"` default fires only on a
    //! NULL `const char*` which daslang's string binding doesn't expose).
    let im_open = BeginPopupContextWindow(str_id, flags)
    if (im_open) {
        invoke(blk)
        EndPopup()
    }
    stateless_finalize(widget_ident, "popup_context_window", state)
}

[container]
def popup_window(var state : PopupWindowState; str_id : string;
                 flags : ImGuiWindowFlags; blk : block) {
    //! `BeginPopup(str_id, flags)` / `EndPopup()` — stateless manual-trigger
    //! pairing. Unlike `popup_context_item`/`popup_context_window` (which
    //! attach an auto-trigger to a preceding item or the enclosing window),
    //! `popup_window` does NOT open itself. Caller drives opening via
    //! `open_popup(str_id, flags)` — typically on a hover + mouse-release
    //! check, or any other custom predicate. Body runs only while ImGui
    //! reports the popup as open under `str_id`.
    //!
    //! When the same `str_id` is reused under different `PushID` scopes
    //! (e.g. one logical popup per loop iteration with shared text), each
    //! scope keeps its own open state — see `examples/features/popup_window.das`.
    //!
    //! IDENT-vs-str_id ID stacking: the boost ``[container]`` prelude
    //! pushes ``widget_ident`` onto ImGui's ID stack before the body runs,
    //! but ``OpenPopup(str_id)`` was called by the caller OUTSIDE that
    //! push. To keep BeginPopup's hash matching the caller's OpenPopup
    //! hash, ``popup_window`` peels ``widget_ident`` off the ID stack just
    //! around ``BeginPopup``/``EndPopup`` — the body still renders under
    //! the pushed IDENT so child widgets remain disambiguated.
    PopID()
    let im_open = BeginPopup(str_id, flags)
    PushID(widget_ident)
    if (im_open) {
        invoke(blk)
        EndPopup()
    }
    stateless_finalize(widget_ident, "popup_window", state)
}

[container]
def popup_modal(var state : PopupState; text : string; closable : bool;
                flags : ImGuiWindowFlags; blk : block) {
    //! `BeginPopupModal(name, p_open, flags)` / `EndPopup()`. Same lifecycle
    //! as `popup`; with `closable=true`, ImGui's X-button is wired to
    //! `state.open` (the click flips it false and ImGui will route a close).
    if (state.pending_open) {
        OpenPopup(text, ImGuiPopupFlags.None)
        state.open = true
        state.pending_open = false
    }
    state.flags = flags
    var p_open : bool? = null
    if (closable) {
        unsafe {
            p_open = addr(state.open)
        }
    }
    let im_open = BeginPopupModal(text, p_open, flags)
    if (im_open) {
        if (state.pending_close) {
            CloseCurrentPopup()
            state.open = false
            state.pending_close = false
        }
        invoke(blk)
        EndPopup()
    } else {
        state.open = false
        state.pending_close = false
    }
    open_close_finalize(widget_ident, "popup_modal", state)
}

// ===== Popup control (trigger paired with popup / popup_modal containers) =====

def open_popup(var state : PopupState) : void {
    //! Queue `OpenPopup(state.text)` for the next visit of the paired
    //! `popup` / `popup_modal` container — the container reads
    //! `pending_open` before `BeginPopup`, so the linkage button-click →
    //! popup is observable as a state mutation (visible to live/mouse-cards).
    state.pending_open = true
}

def open_popup(str_id : string;
               flags : ImGuiPopupFlags = ImGuiPopupFlags.None) : void {
    //! String-id form for stateless popups (paired with `popup_context_item`).
    //! No telemetry — open-state lives in ImGui internals.
    OpenPopup(str_id, flags)
}

def open_popup_on_item_click(str_id : string;
                             flags : ImGuiPopupFlags = ImGuiPopupFlags.MouseButtonRight) : void {
    //! Right-click on the previously-submitted item opens `str_id` popup.
    //! Stateless trigger paired with `popup_context_item`.
    OpenPopupOnItemClick(str_id, flags)
}

def open_popup_on_item_click(var state : PopupState;
                             flags : ImGuiPopupFlags = ImGuiPopupFlags.MouseButtonRight) : void {
    //! Stateful right-click trigger paired with `popup` / `popup_modal`
    //! containers. Checks ``IsMouseReleased`` + ``IsItemHovered`` on the
    //! previously-submitted item, then queues ``state.pending_open`` so the
    //! container's NEXT visit opens the popup INSIDE its own
    //! ``PushID(IDENT)`` scope. The string-id form
    //! (:ref:`open_popup_on_item_click(str_id, …) <function-imgui_containers_builtin_open_popup_on_item_click_string_ImGuiPopupFlags>`)
    //! computes ``GetID(str_id)`` at the call-site ID stack, which DOES NOT
    //! match a registered ``popup`` container's ``BeginPopup`` ID (the
    //! container does its own ``PushID(IDENT)`` first) — so the popup never
    //! opens. Use this overload whenever the target popup is a
    //! ``popup(IDENT, …)`` / ``popup_modal(IDENT, …)`` container.
    let mb = int(flags) & int(ImGuiPopupFlags.MouseButtonMask_)
    if (IsMouseReleased(unsafe(reinterpret<ImGuiMouseButton>(mb)))
            && IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByPopup)) {
        state.pending_open = true
    }
}

def close_current_popup(var state : PopupState) : void {
    //! Close the active popup. Sets `pending_close` for state-transition
    //! telemetry AND calls `CloseCurrentPopup()` directly so the close
    //! takes effect on the current frame (matches raw-call semantics).
    state.pending_close = true
    CloseCurrentPopup()
}

def close_current_popup() : void {
    //! No-state form for body-internal use where a `PopupState` ident isn't
    //! in scope (e.g., inside `popup_context_item`, which is stateless).
    CloseCurrentPopup()
}

def is_popup_open(state : PopupState) : bool {
    //! True while the paired popup container is open this frame.
    return state.open
}

// ===== Tab family =====

[container]
def tab_bar(var state : TabBarState; text : string;
            flags : ImGuiTabBarFlags; blk : block) {
    //! `BeginTabBar(id, flags)` / `EndTabBar()` — only-on-true pairing.
    //! Active-tab selection lives in ImGui's internal storage; we just
    //! observe via the body of each tab_item.
    state.flags = flags
    let im_open = BeginTabBar(text, flags)
    if (im_open) {
        invoke(blk)
        EndTabBar()
    }
    stateless_finalize(widget_ident, "tab_bar", state)
}

[container]
def tab_item(var state : TabItemState; text : string; closable : bool;
             flags : ImGuiTabItemFlags; blk : block) {
    //! `BeginTabItem(label, p_open, flags)` / `EndTabItem()` — only-on-true.
    //! With `closable=true` the X-button toggles `state.open`; we skip
    //! BeginTabItem entirely once `state.open` is false. `state.open` defaults
    //! to true (see TabItemState) so closable tabs render from frame 1.
    if (state.pending_open) {
        state.open = true
        state.pending_open = false
    }
    if (state.pending_close) {
        state.open = false
        state.pending_close = false
    }
    state.flags = flags
    if (!closable || state.open) {
        var p_open : bool? = null
        if (closable) {
            unsafe {
                p_open = addr(state.open)
            }
        }
        let im_open = BeginTabItem(text, p_open, flags)
        //! Same rationale as ``menu()``: the tab strip header is the
        //! ``IsItem*`` target right after BeginTabItem. Inside the body
        //! ``last item`` shifts to per-widget items and EndTabItem pops it.
        let header_bbox = current_item_bbox()
        if (im_open) {
            invoke(blk)
            EndTabItem()
        }
        open_close_finalize(widget_ident, "tab_item", state, header_bbox)
    } else {
        open_close_finalize(widget_ident, "tab_item", state)
    }
}

[edit_container]
def edit_tab_item(var p_open : bool? implicit; text : string;
                  flags : ImGuiTabItemFlags; blk : block) {
    //! ``BeginTabItem(label, p_open, flags)`` / ``EndTabItem()`` against a
    //! caller-owned ``bool?``. External-pointer sibling of :ref:`tab_item
    //! <function-imgui_containers_builtin_tab_item>`: when ``*p_open == false``
    //! the tab is skipped entirely (chrome + body); the X close button on the
    //! header writes ``*p_open = false``. Use when a second UI surface
    //! (checkbox row, menu toggle, etc.) needs to drive the same visibility
    //! flag the X button writes — the canonical "shared open state" pattern
    //! that ``tab_item``'s internal-only ``state.open`` doesn't expose. Same
    //! ``id="..."`` literal requirement as other ``edit_*`` rails.
    var header_bbox = float4(0.0f, 0.0f, 0.0f, 0.0f)
    if (unsafe(*p_open)) {
        let im_open = BeginTabItem(text, p_open, flags)
        // Same rationale as `tab_item`: the tab strip header is the IsItem*
        // target right after BeginTabItem; capture its bbox before the body
        // pushes inner items.
        header_bbox = current_item_bbox()
        if (im_open) {
            invoke(blk)
            EndTabItem()
        }
    }
    edit_container_open_close_finalize(widget_ident, "edit_tab_item", p_open, header_bbox)
}

// ===== Tooltip family =====

[container]
def tooltip(var state : TooltipState; blk : block) {
    //! `BeginTooltip()` / `EndTooltip()` — only-on-true pairing in modern ImGui.
    //! Caller is responsible for the IsItemHovered gate (or any other gate)
    //! around invoking this widget — tooltips render every frame they're
    //! reached otherwise. For the "show only when item hovered" idiom, use
    //! `item_tooltip` instead.
    let im_open = BeginTooltip()
    if (im_open) {
        invoke(blk)
        EndTooltip()
    }
    stateless_finalize(widget_ident, "tooltip", state)
}

[container]
def item_tooltip(var state : TooltipState; blk : block) {
    //! `BeginItemTooltip()` / `EndTooltip()` — only-on-true. Equivalent to
    //! `if (IsItemHovered()) { BeginTooltip(); ...; EndTooltip(); }` but
    //! with ImGui's lazy-evaluation of the hover gate.
    let im_open = BeginItemTooltip()
    if (im_open) {
        invoke(blk)
        EndTooltip()
    }
    stateless_finalize(widget_ident, "item_tooltip", state)
}

// ===== Tree family =====

[container]
def tree_node(var state : TreeNodeState; text : string;
              flags : ImGuiTreeNodeFlags; blk : block) {
    //! `TreeNodeEx(label, flags) : bool` paired with `TreePop()` only when
    //! the node returned true (i.e. the user expanded it). `imgui_open` /
    //! `imgui_close` route through `SetNextItemOpen` so the next frame's
    //! TreeNodeEx call already reflects the requested state.
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
    if (im_open) {
        invoke(blk)
        TreePop()
    }
    open_close_finalize(widget_ident, "tree_node", state)
}

[container]
def collapsing_header(var state : CollapsingHeaderState; text : string;
                      closable : bool; flags : ImGuiTreeNodeFlags; blk : block) {
    //! `CollapsingHeader(label, p_visible, flags) : bool` — same shape as
    //! TreeNode but WITHOUT a TreePop pair (ImGui handles the close on its
    //! own). When `closable=true`, ImGui renders an X-button that flips
    //! `state.open` to false; while `state.open` is false the section is
    //! hidden entirely. Body runs only when the header is expanded AND
    //! (for closable headers) still open.
    if (state.pending_open) {
        SetNextItemOpen(true, ImGuiCond.Always)
        state.open = true
        state.pending_open = false
    }
    if (state.pending_close) {
        SetNextItemOpen(false, ImGuiCond.Always)
        state.pending_close = false
    }
    state.flags = flags
    var im_open : bool
    if (closable) {
        if (state.open) {
            unsafe {
                im_open = CollapsingHeader(text, addr(state.open), flags)
            }
        }
        // If state.open is false, the section is hidden — don't issue the
        // ImGui call. CollapsingHeader-with-p_visible only renders while
        // *p_visible is true; we mirror that gate exactly.
    } else {
        im_open = CollapsingHeader(text, flags)
    }
    state.opened = im_open
    if (im_open) {
        invoke(blk)
    }
    open_close_finalize(widget_ident, "collapsing_header", state)
}

// ===== Choice block-arg family =====
//
// `combo_select` is the BeginCombo counterpart to the leaf `combo` widget.
// `list_box` is unified on the BeginListBox/EndListBox form — the legacy
// items-array `[widget] def list_box` was dropped (modern ImGui idiom is
// Begin/End + Selectable). Both reuse selection state structs (ComboState /
// ListBoxState) — `value : int` is the user-driven selection index. Body
// code emits Selectable items; the dispatcher's "set" action writes
// `state.value` for the next frame. Per-call args follow the named-tuple convention.

[container]
def combo_select(var state : ComboState; text : string; preview_value : string;
                 flags : ImGuiComboFlags; blk : block) {
    //! `BeginCombo(label, preview, flags)` / `EndCombo()` — only-on-true.
    //! `preview_value` is the closed-state label; the body emits the
    //! per-item Selectable rows. Pending value flow matches the leaf combo.
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let im_open = BeginCombo(text, preview_value, flags)
    if (im_open) {
        invoke(blk)
        EndCombo()
    }
    var entry : WidgetEntry
    unsafe {
        container_finalize(widget_ident, "combo_select", entry,
                           addr(state),
                           reinterpret<TypeInfo const?>(typeinfo rtti_typeinfo(type<ComboState>)))
    }
}

[container]
def list_box(var state : ListBoxState; text : string; size : float2; blk : block) {
    //! `BeginListBox(label, size)` / `EndListBox()` — only-on-true. Body
    //! emits the per-item rows. `imgui_set {"value":N}` steers next-frame
    //! selection; bodies typically read `state.value` to tag the active row.
    if (state.has_pending) {
        state.value = state.pending_value
        state.has_pending = false
    }
    let im_open = BeginListBox(text, size)
    if (im_open) {
        invoke(blk)
        EndListBox()
    }
    var entry : WidgetEntry
    unsafe {
        container_finalize(widget_ident, "list_box", entry,
                           addr(state),
                           reinterpret<TypeInfo const?>(typeinfo rtti_typeinfo(type<ListBoxState>)))
    }
}

// ===== Drag-drop family =====
//
// Both bodies are gated on ImGui's internal drag-drop state machine:
// `drag_drop_source` body runs only when the previous item has been picked
// up for drag; `drag_drop_target` body runs only when a payload-bearing
// drag is hovering. Payload set/accept are raw `SetDragDropPayload` /
// `AcceptDragDropPayload` calls inside the body — no boost wrapper, since
// the payload data is caller-owned and crosses widget boundaries.

[container]
def drag_drop_source(var state : DragDropSourceState; flags : ImGuiDragDropFlags;
                     blk : block) {
    //! `BeginDragDropSource(flags)` / `EndDragDropSource()` — only-on-true.
    //! Body calls `SetDragDropPayload(type, data, sz, cond)` to publish the
    //! payload and renders the drag preview (Text, Image, etc.).
    let im_open = BeginDragDropSource(flags)
    if (im_open) {
        invoke(blk)
        EndDragDropSource()
    }
    stateless_finalize(widget_ident, "drag_drop_source", state)
}

[container]
def drag_drop_target(var state : DragDropTargetState; blk : block) {
    //! `BeginDragDropTarget()` / `EndDragDropTarget()` — only-on-true.
    //! Body calls `AcceptDragDropPayload(type, flags)` to receive the payload
    //! when the drag releases over this target.
    let im_open = BeginDragDropTarget()
    if (im_open) {
        invoke(blk)
        EndDragDropTarget()
    }
    stateless_finalize(widget_ident, "drag_drop_target", state)
}

// ===== Per-state-struct dispatchers (containers) =====
//
// One [widget_dispatch] body per state struct. Dispatch keyed by ti.hash
// fires for every container kind whose state is that struct (popup +
// popup_modal share PopupState etc.). TreeNodeState/ComboState/ListBoxState
// dispatchers live in imgui_widgets_builtin.das; their dispatchers also
// cover the container forms (tree_node, combo_select, list_box) without
// extra registration. Stateless containers (group/menu/popup_context*/
// tab_bar/tooltip/drag_drop_*) get no dispatcher and silently no-op.

[widget_dispatch]
def _window_dispatch(var state : WindowState; action : string; payload : string) {
    if (action == "open") {
        state.pending_open = true
    } elif (action == "close") {
        state.pending_close = true
    } elif (action == "set_window_size") {
        // Payload: ``{w, h}`` — both optional, falling back to the current
        // observed size. Used by record_window_size_constraints to demonstrate
        // SetNextWindowSizeConstraints callbacks (snap/aspect/quantize) by
        // requesting odd sizes and watching the constraint reshape them.
        var perr : string
        let v = read_json(payload, perr)
        if (v != null) {
            state.pending_size = float2(v?["w"] ?? state.size.x,
                                        v?["h"] ?? state.size.y)
            state.pending_size_set = true
        }
    }
}

[widget_dispatch]
def _popup_dispatch(var state : PopupState; action : string; payload : string) {
    if (action == "open") {
        state.pending_open = true
    } elif (action == "close") {
        state.pending_close = true
    }
}

[widget_dispatch]
def _tab_item_dispatch(var state : TabItemState; action : string; payload : string) {
    if (action == "open") {
        state.pending_open = true
    } elif (action == "close") {
        state.pending_close = true
    }
}

[widget_dispatch]
def _collapsing_header_dispatch(var state : CollapsingHeaderState; action : string; payload : string) {
    if (action == "open") {
        state.pending_open = true
    } elif (action == "close") {
        state.pending_close = true
    }
}
