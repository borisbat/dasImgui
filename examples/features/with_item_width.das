options gen2
options _no_imgui_legacy = true

require imgui
require imgui/imgui_lint
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
// FEATURE: with_item_width — stateless block-arg wrapper around
//          PushItemWidth/PopItemWidth. Scoped widget-width override that
//          auto-restores on block exit.
// SHOWS:   nested scopes; positive (absolute), negative (right-edge minus N),
//          and default style width contrasted side-by-side.
// STANDALONE: daslang.exe modules/dasImgui/examples/features/with_item_width.das
// LIVE:       daslang-live modules/dasImgui/examples/features/with_item_width.das
// =============================================================================

[export]
def init() {
    live_create_window("with_item_width — scope wrapper", 720, 480)
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

    SetNextWindowSize(ImVec2(660.0, 420.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "with_item_width", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text("Default width (ImGui style):")
        slider_float(DEFAULT_W, (text = "default", bounds = (0.0f, 1.0f)))

        separator()
        text("Absolute 120 px:")
        with_item_width(120.0f) {
            slider_float(NARROW_W, (text = "120px", bounds = (0.0f, 1.0f)))
        }

        text("Absolute 320 px:")
        with_item_width(320.0f) {
            slider_float(WIDE_W, (text = "320px", bounds = (0.0f, 1.0f)))
        }

        separator()
        text("Right-edge minus 60 px (negative):")
        with_item_width(-60.0f) {
            slider_float(STRETCH_W, (text = "stretch", bounds = (0.0f, 1.0f)))
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
