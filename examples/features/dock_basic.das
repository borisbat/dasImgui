options gen2

require imgui
require imgui_app
require glfw/glfw_boost
require opengl/opengl_boost
require live/glfw_live
require live/live_api
require live/live_commands
require live/live_vars
require live/opengl_live
require live_host
require imgui/imgui_live
require imgui/imgui_boost_runtime
require imgui/imgui_boost_v2
require imgui/imgui_widgets_builtin
require imgui/imgui_docking_builtin
require imgui/imgui_visual_aids

// =============================================================================
// FEATURE: dock_basic — Phase 7 dockspace + dock_window with a DockBuilder-
//                       seeded 4-panel initial layout.
// SHOWS:   - `dockspace(DOCK_ROOT, (flags=PassthruCentralNode))` — full-viewport
//            DockSpaceOverViewport with a captured `state.dock_id`.
//          - `dock_window(NAME, (text=..., closable=false, flags=...))` — each
//            of Explorer / Source / Properties / Output Begin/End-ed inside.
//          - `setup_default_layout()` — DockBuilderRemoveNode → AddDockSpaceNode
//            → SetNodeSize → 3× SplitNode → DockWindow → Finish. Gated on
//            `state.has_initial_layout` so it runs once per session (or after
//            `imgui_dock_reset`).
//          - Live commands: imgui_dock / imgui_undock / imgui_dock_reset all
//            route through dispatcher lambdas installed by dock_window_finalize
//            / dockspace_finalize.
//          - `apply_synth_io_override()` for playwright drag/click coverage.
// DRIVE:   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command
//          curl -X POST -d '{"name":"imgui_undock","args":{"target":"DOCK_ROOT/OUTPUT"}}' \
//                       localhost:9090/command
//          curl -X POST -d '{"name":"imgui_set_window_pos","args":{"target":"DOCK_ROOT/OUTPUT","value":{"x":580,"y":220,"w":360,"h":220}}}' \
//                       localhost:9090/command
//          curl -X POST -d '{"name":"imgui_dock_reset","args":{"target":"DOCK_ROOT"}}' \
//                       localhost:9090/command
//
// Note: dockspace is a [container] that pushes its identifier onto the registry
// path, so child dock_windows live under ``DOCK_ROOT/<name>`` — mirrors how
// ``window(MAIN_WIN, ...)`` prefixes its children in containers_builtin.
// STANDALONE: daslang.exe modules/dasImgui/examples/features/dock_basic.das
// LIVE:       daslang-live modules/dasImgui/examples/features/dock_basic.das
// =============================================================================

def setup_default_layout(dock_id : uint) {
    //! Seed a 4-panel layout:
    //!     +----------+--------------------+
    //!     |          |       Source       |
    //!     | Explorer +---------+----------+
    //!     |          |         | Properties
    //!     |          | Output  |          |
    //!     +----------+---------+----------+
    DockBuilderRemoveNode(dock_id)
    DockBuilderAddDockSpaceNode(dock_id, ImGuiDockNodeFlags.None)
    let vp = GetMainViewport()
    let vp_size = ImVec2(vp.Size.x, vp.Size.y)
    DockBuilderSetNodeSize(dock_id, vp_size)
    var left_id : uint = 0u
    var main_id : uint = 0u
    DockBuilderSplitNode(dock_id, ImGuiDir.Left, 0.22f, left_id, main_id)
    var top_id : uint = 0u
    var bottom_id : uint = 0u
    DockBuilderSplitNode(main_id, ImGuiDir.Up, 0.55f, top_id, bottom_id)
    var bl_id : uint = 0u
    var br_id : uint = 0u
    DockBuilderSplitNode(bottom_id, ImGuiDir.Left, 0.55f, bl_id, br_id)
    DockBuilderDockWindow("Explorer",   left_id)
    DockBuilderDockWindow("Source",     top_id)
    DockBuilderDockWindow("Output",     bl_id)
    DockBuilderDockWindow("Properties", br_id)
    DockBuilderFinish(dock_id)
}

[export]
def init() {
    live_create_window("Phase 7 — docking", 1024, 720)
    live_imgui_init(live_window)
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.5
    io.ConfigFlags |= ImGuiConfigFlags.DockingEnable
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()

    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    apply_synth_io_override()
    NewFrame()

    dockspace(DOCK_ROOT, (flags = ImGuiDockNodeFlags.PassthruCentralNode)) {
        //! Seed the layout once per session (or after imgui_dock_reset flips
        //! has_initial_layout back to false). state.dock_id is valid after the
        //! first DockSpaceOverViewport return — the dockspace wrapper captures
        //! it before invoking this block.
        if (!DOCK_ROOT.has_initial_layout && DOCK_ROOT.dock_id != 0u) {
            setup_default_layout(DOCK_ROOT.dock_id)
            DOCK_ROOT.has_initial_layout = true
        }
        dock_window(EXPLORER, (text = "Explorer", closable = false,
                               flags = ImGuiWindowFlags.None)) {
            Text("Files")
            button(REFRESH_BTN, (text = "Refresh"))
            button(NEW_FILE_BTN, (text = "New file"))
        }
        dock_window(SOURCE, (text = "Source", closable = false,
                             flags = ImGuiWindowFlags.None)) {
            Text("Editor area")
            button(SAVE_BTN, (text = "Save"))
        }
        dock_window(OUTPUT, (text = "Output", closable = true,
                             flags = ImGuiWindowFlags.None)) {
            Text("> ready.")
            button(CLEAR_BTN, (text = "Clear"))
        }
        dock_window(PROPERTIES, (text = "Properties", closable = false,
                                 flags = ImGuiWindowFlags.None)) {
            Text("Inspector")
            button(APPLY_BTN, (text = "Apply"))
        }
    }

    end_of_frame()
    Render()
    var w, h : int
    live_get_framebuffer_size(w, h)
    glViewport(0, 0, w, h)
    glClearColor(0.10f, 0.10f, 0.12f, 1.0f)
    glClear(GL_COLOR_BUFFER_BIT)
    ImGui_ImplOpenGL3_RenderDrawData(GetDrawData())

    live_end_frame()
}

[export]
def shutdown() {
    live_imgui_shutdown()
    live_destroy_window()
}

[export]
def main() {
    init()
    while (!exit_requested()) {
        update()
    }
    shutdown()
}
