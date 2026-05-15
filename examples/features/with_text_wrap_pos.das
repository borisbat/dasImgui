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
// FEATURE: with_text_wrap_pos — stateless block-arg wrapper around
//          PushTextWrapPos/PopTextWrapPos. Scoped wrap-x override for long
//          text passed to TextWrapped or TextUnformatted.
// SHOWS:   default wrap (window right edge), narrow wrap (200 px), wider
//          wrap (400 px).
// STANDALONE: daslang.exe modules/dasImgui/examples/features/with_text_wrap_pos.das
// LIVE:       daslang-live modules/dasImgui/examples/features/with_text_wrap_pos.das
// =============================================================================

let LIPSUM = ("Lorem ipsum dolor sit amet, consectetur adipiscing elit, "
              + "sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")

[export]
def init() {
    live_create_window("with_text_wrap_pos — scope wrapper", 720, 540)
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

    SetNextWindowSize(ImVec2(660.0, 480.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "with_text_wrap_pos", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text("Default wrap (0.0f → window right edge):")
        with_text_wrap_pos(0.0f) {
            text_unformatted((text = LIPSUM))
        }

        separator()
        text("Wrap at 200 px:")
        with_text_wrap_pos(200.0f) {
            text_unformatted((text = LIPSUM))
        }

        separator()
        text("Wrap at 400 px:")
        with_text_wrap_pos(400.0f) {
            text_unformatted((text = LIPSUM))
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
