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
require daslib/safe_addr
require math

// =============================================================================
// FEATURE: edit_external_special — slider_angle on external float? pointer.
// SHOWS:   edit_slider_angle(safe_addr(rad_value), (id=…, text=…,
//                              v_degrees_min=-180, v_degrees_max=180,
//                              format="%.0f°")). The pointee is RADIANS;
//          the slider displays + edits DEGREES via ImGui's internal
//          conversion. Useful for rotation editors backed by quaternion /
//          matrix math storage on the daslang side.
// DRIVE:   curl -X POST -d '{"name":"imgui_set","args":{"target":"MAIN_WIN/ANGLE","value":1.5707}}' \
//              localhost:9090/command
//          # → sets g_angle_rad to ~π/2 (90° on the slider).
// STANDALONE: daslang.exe modules/dasImgui/examples/features/edit_external_special.das
// LIVE:       daslang-live modules/dasImgui/examples/features/edit_external_special.das
// =============================================================================

var private g_angle_rad : float = 0.7854f  // π/4 → ~45° initial

[export]
def init() {
    live_create_window("edit_external_special — boost v2 §3.7", 720, 320)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(680.0, 260.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "edit_slider_angle", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text(LEAD, (text = "Slider reads/writes radians; UI displays degrees."))
        edit_slider_angle(safe_addr(g_angle_rad), (id = "ANGLE",
                                                   text = "rotation",
                                                   v_degrees_min = -180.0f,
                                                   v_degrees_max = 180.0f,
                                                   format = "%.0f deg"))
        text(STATUS, (text = "g_angle_rad = {g_angle_rad} (≈ {int(g_angle_rad * 180.0f / PI)}°)"))
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
