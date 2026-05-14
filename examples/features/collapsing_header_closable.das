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
// FEATURE: collapsing_header(closable=true) — close-button route (boost v2 §3.5).
// SHOWS:   With closable=true, the header surfaces an X button. Click hides
//          the section entirely (the body skips, the chrome disappears) per
//          ImGui's `bool* p_visible` overload contract. Reopen via
//          `imgui_open` against the path key — the state.pending_open flag
//          flips state.open back to true and the next frame re-renders.
// DRIVE:   curl -X POST -d '{"name":"imgui_open","args":{"target":"MAIN_WIN/HEADER_CLOSE"}}' \
//              localhost:9090/command
// STANDALONE: daslang.exe modules/dasImgui/examples/features/collapsing_header_closable.das
// LIVE:       daslang-live modules/dasImgui/examples/features/collapsing_header_closable.das
// =============================================================================

[export]
def init() {
    live_create_window("collapsing_header_closable — boost v2 §3.5", 720, 420)
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
    window(MAIN_WIN, (text = "collapsing_header(closable=…)",
                      closable = false, flags = ImGuiWindowFlags.None)) {
        text(LEAD, (text = "Two collapsing headers — first closable (X button), second not."))

        collapsing_header(HEADER_CLOSE, (text = "Closable section",
                                          closable = true,
                                          flags = ImGuiTreeNodeFlags.None)) {
            text(BODY_CLOSE_1, (text = "Body of closable header. Click the X to hide."))
            text(BODY_CLOSE_2, (text = "Re-open via imgui_open MAIN_WIN/HEADER_CLOSE."))
            if (button(REVEAL_BTN, (text = "I'm only visible while open"))) {}
        }

        collapsing_header(HEADER_STD, (text = "Standard (non-closable) section",
                                        closable = false,
                                        flags = ImGuiTreeNodeFlags.None)) {
            text(BODY_STD, (text = "No X button — header collapses via the caret arrow only."))
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
