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
// FEATURE: with_button_repeat — stateless Push/PopButtonRepeat wrapper.
// SHOWS:   `with_button_repeat(true) { ... }` makes any button inside fire
//          repeatedly while held (typical use: increment/decrement chevron
//          rows in numeric editors). Outside the block, buttons go back to
//          fire-once semantics. Compare BTN_INSIDE.click_count vs
//          BTN_OUTSIDE.click_count while holding each.
// STANDALONE: daslang.exe modules/dasImgui/examples/features/button_repeat.das
// LIVE:       daslang-live modules/dasImgui/examples/features/button_repeat.das
// =============================================================================

[export]
def init() {
    live_create_window("with_button_repeat — boost v2 §3.6", 720, 360)
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
    window(MAIN_WIN, (text = "with_button_repeat", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text(LEAD, (text = "Hold the inside button — click_count climbs every frame. The outside one fires once per press."))

        with_button_repeat(true) {
            if (button(BTN_INSIDE, (text = "repeat (hold)"))) {}
            same_line(LAY_GAP)
            text(STATUS_IN, (text = "inside count: {BTN_INSIDE.click_count}"))
        }

        if (button(BTN_OUTSIDE, (text = "fire-once (hold)"))) {}
        same_line(LAY_GAP2)
        text(STATUS_OUT, (text = "outside count: {BTN_OUTSIDE.click_count}"))
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
