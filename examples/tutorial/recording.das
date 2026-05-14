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
require imgui/imgui_visual_aids

// =============================================================================
// TUTORIAL: recording — the meta tutorial.
//
// Every previous tutorial's APNG was produced by the same workflow:
//
//   shell 1: daslang-live  hosts a SUBJECT app          (this .das)
//   shell 2: daslang       runs a DRIVER script that:
//              - turns on imgui_mouse_trail + imgui_cursor_sprite
//              - calls record_start
//              - posts imgui_narrate before each interaction
//              - moves the cursor / clicks / drags / sets values
//              - calls record_stop
//
// The DRIVER is the artifact that teaches recording — the subject is
// just whatever app you want to record. This file is intentionally tiny
// (one slider, one button) so the recording recipe is obvious: every
// frame of the APNG corresponds to one specific driver call.
//
// The driver script for this tutorial is:
//   tests/integration/record_recording.das
//
// Read the driver alongside the walkthrough in the RST companion — the
// .das + driver + APNG triple is the tutorial.
//
// STANDALONE: daslang.exe modules/dasImgui/examples/tutorial/recording.das
// LIVE:       daslang-live modules/dasImgui/examples/tutorial/recording.das
//
// DRIVE: see tests/integration/record_recording.das
// =============================================================================

[export]
def init() {
    live_create_window("dasImgui recording tutorial", 600, 380)
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
    apply_synth_io_override()
    NewFrame()

    SetNextWindowPos(ImVec2(30.0f, 30.0f), ImGuiCond.FirstUseEver)
    SetNextWindowSize(ImVec2(520.0f, 280.0f), ImGuiCond.FirstUseEver)
    window(REC_WIN, (text = "subject", closable = false,
                     flags = ImGuiWindowFlags.None)) {
        text("Tiny subject — driver narrates what's happening.")
        slider_float(VOLUME, (text = "Volume"))
        if (button(SAVE_BTN, (text = "Save"))) {}
        text((text = "SAVE_BTN.click_count = {SAVE_BTN.click_count}"))
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
