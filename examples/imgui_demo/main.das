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

require imgui_demo

// =============================================================================
// EXAMPLE: imgui_demo — daslang port of Dear ImGui's imgui_demo.cpp.
// SHOWS:   complete tour of the dasImgui boost surface as a single host file
//          dispatching into per-section sub-modules under imgui_demo/.
// STANDALONE: daslang.exe modules/dasImgui/examples/imgui_demo/main.das
// LIVE:       daslang-live modules/dasImgui/examples/imgui_demo/main.das
// =============================================================================

[export]
def init() {
    live_create_window("Dear ImGui Demo (daslang port)", 1280, 720)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()

    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    RunImGuiDemo()

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
