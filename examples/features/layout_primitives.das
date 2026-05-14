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
require imgui/imgui_containers_builtin

// =============================================================================
// FEATURE: layout_primitives — same_line / new_line / spacing / dummy.
// SHOWS:   Four EmptyMarkerState siblings of separator. Each emits a `{}`
//          payload under its IDENT so playwright can assert presence and
//          ordering without needing payload content. `dummy(size=...)` is
//          the only one that's argument-bearing — useful for grid spacers.
// DRIVE:   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command \
//              | jq '.globals|keys|map(select(startswith("MAIN_WIN/LAY_")))'
// STANDALONE: daslang.exe modules/dasImgui/examples/features/layout_primitives.das
// LIVE:       daslang-live modules/dasImgui/examples/features/layout_primitives.das
// =============================================================================

[export]
def init() {
    live_create_window("layout_primitives — boost v2 §3.2", 720, 420)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(680.0, 360.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "same_line / new_line / spacing / dummy",
                      closable = false, flags = ImGuiWindowFlags.None)) {
        text(LAY_LEAD, (text = "Four EmptyMarkerState siblings. Each is telemetry-visible."))

        // same_line — explicit horizontal continuation
        if (button(BTN_A, (text = "A"))) {}
        same_line(LAY_SAME_LINE)
        if (button(BTN_B, (text = "B"))) {}
        same_line(LAY_SAME_LINE_2, (offset_x = 0.0f, spacing = 20.0f))
        if (button(BTN_C, (text = "C"))) {}

        spacing(LAY_SPACING_ROW)

        // dummy — zero-content rectangle that consumes layout space
        text(LAY_DUMMY_PREV, (text = "before dummy"))
        dummy(LAY_DUMMY, (size = float2(60.0f, 30.0f)))
        text(LAY_DUMMY_NEXT, (text = "after dummy (offset by 60×30)"))

        new_line(LAY_NEW_LINE)
        text(LAY_AFTER_NEW, (text = "after new_line — guaranteed fresh row."))
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
