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
require imgui/imgui_scope_builtin

// =============================================================================
// FEATURE: with_indent — stateless block-arg wrapper around Indent/Unindent.
// SHOWS:   nested with_indent blocks; default amount (0.0f) defers to ImGui's
//          style IndentSpacing, explicit amounts produce custom indents.
// STANDALONE: daslang.exe modules/dasImgui/examples/features/with_indent.das
// LIVE:       daslang-live modules/dasImgui/examples/features/with_indent.das
// =============================================================================

[export]
def init() {
    live_create_window("with_indent — scope wrapper", 640, 480)
    live_imgui_init(live_window)
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.5
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()

    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(580.0, 420.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "with_indent", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text("Default indent (0.0f uses style IndentSpacing):")
        with_indent(0.0f) {
            text("Level 1")
            with_indent(0.0f) {
                text("Level 2")
                with_indent(0.0f) {
                    text("Level 3")
                }
            }
        }

        separator()
        text("Custom amounts:")
        with_indent(40.0f) {
            text("indent 40px")
        }
        with_indent(80.0f) {
            text("indent 80px")
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
