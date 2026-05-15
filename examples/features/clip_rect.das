options gen2
// Demos the low-level ImDrawList API (GetWindowDrawList + AddCircleFilled).
// No v2 wrappers exist for direct drawlist primitives; opt out of the
// default-on lint so the demo compiles cleanly.
options _allow_imgui_legacy = true

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
// FEATURE: with_clip_rect — Push/PopClipRect scope wrapper.
// SHOWS:   `with_clip_rect(min, max, intersect) { ... }` restricts every draw
//          inside to the given rectangle. Typical use: rendering DrawList
//          shapes that should not bleed outside a widget box.
// STANDALONE: daslang.exe modules/dasImgui/examples/features/clip_rect.das
// LIVE:       daslang-live modules/dasImgui/examples/features/clip_rect.das
// =============================================================================

[export]
def init() {
    live_create_window("with_clip_rect — boost v2 §3.6", 720, 480)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(680.0, 420.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "with_clip_rect", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text(LEAD, (text = "Clip rect confines the draw-list shapes below to a 200×80 box."))

        let topleft = GetCursorScreenPos()
        let clip_min = ImVec2(topleft.x, topleft.y)
        let clip_max = ImVec2(topleft.x + 200.0, topleft.y + 80.0)

        with_clip_rect(float2(clip_min.x, clip_min.y),
                       float2(clip_max.x, clip_max.y), true) {
            var dl & = unsafe(*GetWindowDrawList())
            // Two overlapping circles — both extend beyond the clip box; the
            // wrapper crops them to the rectangle.
            unsafe {
                dl.AddCircleFilled(ImVec2(clip_min.x + 80.0, clip_min.y + 40.0),
                                   80.0, 0xFFAA4400u, 0)
                dl.AddCircleFilled(ImVec2(clip_min.x + 160.0, clip_min.y + 40.0),
                                   80.0, 0xFF0099FFu, 0)
            }
            dummy(GUARD, (size = float2(200.0f, 80.0f)))
        }

        separator(SEP)
        text(NOTE, (text = "Below the clip block — uncropped Text renders normally."))
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
