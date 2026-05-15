options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options _allow_imgui_legacy = true

module imgui_docking_builtin shared

require imgui public
require imgui/imgui_boost_runtime public
require imgui/imgui_boost_v2 public
require daslib/json public
require daslib/json_boost
require math

//! Phase 7 docking — boost wrappers around ImGui's native DockSpace + Begin/End
//! dockable windows. `dockspace(NAME, ...)` creates a full-viewport dockspace
//! and captures its dock_id into `state.dock_id` so user code can call
//! DockBuilder*(state.dock_id) to seed an initial layout. `dock_window(NAME, ...)`
//! is a registry-aware wrapper around Begin/End with `closable` (X-button
//! routes to `state.open`) plus pending-flag plumbing for live commands
//! (imgui_dock / imgui_undock / imgui_focus). Path-prefix on child widgets
//! works the same way as containers_builtin's `window` — `dock_window(EXPLORER)
//! { button(REFRESH_BTN, ...) }` registers `EXPLORER/REFRESH_BTN`.

struct DockSpaceState {
    //! Backs the `dockspace` container. `dock_id` is captured from the
    //! DockSpaceOverViewport return value on the first render; user code reads
    //! it to drive DockBuilder*(state.dock_id) layout calls. `pending_reset`
    //! is set by `imgui_dock_reset`; the renderer clears DockBuilder state
    //! and `has_initial_layout` so the user's setup function runs again.
    @live dock_id : uint = 0u                 //! viewport dockspace id; captured on first render
    @optional has_initial_layout : bool = false //! flips true once user has seeded a layout; user reads this to gate their setup
    @optional flags : ImGuiDockNodeFlags      //! per-call flags (echoed for telemetry)
    @optional pending_reset : bool            //! imgui_dock_reset queued; applied next frame
}

struct DockWindowState {
    //! Backs the `dock_window` container. `open` defaults to true and is
    //! @live so closable windows survive reload (same convention as
    //! WindowState). `docked` / `dock_id` are observed via
    //! IsWindowDocked / GetWindowDockID. `pending_dock_to` / `pending_undock`
    //! flow from live commands; applied via SetNextWindowDockID at top of
    //! next frame. `pending_pos` / `pending_size` route through
    //! `imgui_set_window_pos`; gated on the matching `*_set` bool so
    //! `(0,0)` is a legitimate position request, not a sentinel.
    @live open : bool = true                  //! window open state; preserved across reload
    @optional flags : ImGuiWindowFlags        //! per-call window flags (echoed for telemetry)
    @optional pos : float2                    //! observed window position
    @optional size : float2                   //! observed window size
    @optional docked : bool                   //! observed IsWindowDocked()
    @optional dock_id : uint                  //! observed GetWindowDockID()
    @optional pending_open : bool             //! imgui_open queued; applied next frame
    @optional pending_close : bool            //! imgui_close queued; applied next frame
    @optional pending_dock_to : uint = 0u     //! imgui_dock queued; SetNextWindowDockID(value) next frame
    @optional pending_undock : bool           //! imgui_undock queued; SetNextWindowDockID(0) next frame
    @optional pending_pos : float2            //! imgui_set_window_pos queued — pos
    @optional pending_pos_set : bool          //! gates pending_pos (so (0,0) is a valid request)
    @optional pending_size : float2           //! imgui_set_window_pos queued — size
    @optional pending_size_set : bool         //! gates pending_size
}

// ===== Finalize helpers =====
//
// `dockspace_finalize` installs `imgui_dock_reset`. `dock_window_finalize`
// installs the union of `open`/`close`/`dock`/`undock` actions on a single
// dispatcher lambda — keeps the per-target dispatcher install single-call
// and matches the existing `open_close_finalize` shape in containers_builtin.

def private dockspace_finalize(widget_ident : string; var state : DockSpaceState) {
    let path = container_path_key()
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(= path) () : JsonValue ? {
            return state_jv(path, type<typedecl(state)>)
        }
        let disp <- @ capture(= path) (action : string; payload : JsonValue ?) {
            with_state(path, type<typedecl(state)>) $(var s) {
                if (action == "reset") {
                    s.pending_reset = true
                }
            }
        }
        container_finalize(widget_ident, "dockspace", entry, ser, disp)
    }
}

def private dock_window_finalize(widget_ident : string; var state : DockWindowState) {
    let path = container_path_key()
    var entry : WidgetEntry
    unsafe {
        let ser <- @ capture(= path) () : JsonValue ? {
            return state_jv(path, type<typedecl(state)>)
        }
        let disp <- @ capture(= path) (action : string; payload : JsonValue ?) {
            with_state(path, type<typedecl(state)>) $(var s) {
                if (action == "open") {
                    s.pending_open = true
                } elif (action == "close") {
                    s.pending_close = true
                } elif (action == "dock") {
                    s.pending_dock_to = from_JV(payload?["value"], type<uint>, 0u)
                } elif (action == "undock") {
                    s.pending_undock = true
                } elif (action == "set_window_pos") {
                    //! Payload shape: `{x, y[, w, h]}` — pos always set, size optional.
                    let v = payload?["value"]
                    s.pending_pos = float2(v?["x"] ?? 0.0f, v?["y"] ?? 0.0f)
                    s.pending_pos_set = true
                    let has_w = v?["w"] != null
                    let has_h = v?["h"] != null
                    if (has_w || has_h) {
                        s.pending_size = float2(v?["w"] ?? s.size.x,
                                                v?["h"] ?? s.size.y)
                        s.pending_size_set = true
                    }
                }
            }
        }
        container_finalize(widget_ident, "dock_window", entry, ser, disp)
    }
}

// ===== dockspace =====

[container]
def dockspace(var state : DockSpaceState; flags : ImGuiDockNodeFlags; blk : block) {
    //! Full-viewport dockspace — `DockSpaceOverViewport(GetMainViewport(), flags, null)` paired with the user's block. The body runs unconditionally (the dockspace is always present); dock_window calls inside the body are the dockable panels. `state.dock_id` is captured from the return value so user code can drive `DockBuilder*` layout calls against it. `imgui_dock_reset` flips `has_initial_layout` back to false and removes the DockBuilder node so the user's setup function re-runs.
    if (state.pending_reset) {
        if (state.dock_id != 0u) {
            DockBuilderRemoveNode(state.dock_id)
        }
        state.has_initial_layout = false
        state.pending_reset = false
    }
    state.flags = flags
    let viewport = GetMainViewport()
    let id = DockSpaceOverViewport(viewport, int(flags), null)
    state.dock_id = id
    invoke(blk)
    dockspace_finalize(widget_ident, state)
}

// ===== dock_window =====

[container]
def dock_window(var state : DockWindowState; text : string; closable : bool;
                flags : ImGuiWindowFlags; blk : block) {
    //! Dockable Begin/End window — mirrors `window` from containers_builtin but participates in a dockspace. `closable=true` wires the X-button to `state.open`; `imgui_open`/`imgui_close` route through pending flags. `imgui_dock {"value":<dock_id>}` and `imgui_undock` route through SetNextWindowDockID at the top of the next frame.
    if (state.pending_open) {
        state.open = true
        state.pending_open = false
    }
    if (state.pending_close) {
        state.open = false
        state.pending_close = false
    }
    if (state.pending_dock_to != 0u) {
        SetNextWindowDockID(state.pending_dock_to, ImGuiCond.Always)
        state.pending_dock_to = 0u
    }
    if (state.pending_undock) {
        SetNextWindowDockID(0u, ImGuiCond.Always)
        state.pending_undock = false
    }
    if (state.pending_pos_set) {
        SetNextWindowPos(ImVec2(state.pending_pos.x, state.pending_pos.y), ImGuiCond.Always)
        state.pending_pos_set = false
    }
    if (state.pending_size_set) {
        SetNextWindowSize(ImVec2(state.pending_size.x, state.pending_size.y), ImGuiCond.Always)
        state.pending_size_set = false
    }
    state.flags = flags
    if (!closable || state.open) {
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
            state.docked = IsWindowDocked()
            state.dock_id = GetWindowDockID()
            invoke(blk)
        }
        End()
    }
    dock_window_finalize(widget_ident, state)
}
