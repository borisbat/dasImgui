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
// FEATURE: with_disabled — stateless BeginDisabled / EndDisabled scope wrapper.
// SHOWS:   with_disabled(disabled) { ... } greys out and disables every widget
//          rendered inside without state. Same shape as with_id / with_style —
//          no [container] annotation, no telemetry global. Toggle the gate
//          checkbox to flip every child between active and disabled.
// STANDALONE: daslang.exe modules/dasImgui/examples/features/disabled_block.das
// LIVE:       daslang-live modules/dasImgui/examples/features/disabled_block.das
// =============================================================================

[export]
def init() {
    live_create_window("with_disabled — boost v2 §3.6", 720, 360)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(680.0, 300.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "with_disabled", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text(LEAD, (text = "Toggle the gate to disable every widget inside the block."))
        checkbox(GATE_DISABLED, (text = "disable block below"))
        separator(SEP)

        with_disabled(GATE_DISABLED.value) {
            if (button(BTN_INSIDE, (text = "inside-block button"))) {}
            checkbox(CB_INSIDE, (text = "inside-block checkbox"))
            slider_float(SLIDER_INSIDE, (text = "inside-block slider"))
        }

        separator(SEP_AFTER)
        if (button(BTN_OUTSIDE, (text = "always-enabled button"))) {}
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
