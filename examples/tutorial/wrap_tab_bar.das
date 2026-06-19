options gen2

require daslib/safe_addr
require imgui
require imgui_app
require opengl/opengl_boost
require live/glfw_live
require live/live_api
require live/live_commands
require live/live_vars
require live_host
require imgui/imgui_live
require imgui/imgui_boost_runtime
require imgui/imgui_boost_v2
require imgui/imgui_widgets_builtin
require imgui/imgui_containers_builtin
require imgui/imgui_visual_aids

// =============================================================================
// TUTORIAL: wrap_tab_bar / wrap_tab_item — a multi-row, WRAPPING tab bar.
//
//   wrap_tab_bar(WTB_BAR) {
//       wrap_tab_item("physics") { <body> }
//       wrap_tab_item("camera")  { <body> }
//       ...
//   }
//
// ImGui's native `tab_bar` shrinks/ellipsizes or scrolls its headers when they
// overflow the width; `wrap_tab_bar` instead wraps them onto as many rows as
// needed and shows only the active tab's body. The active tab is an INDEX
// (like `combo`) — `imgui_force_set {"value":N}` selects tab N. Because the
// body renders after the whole header strip, the strip is laid out from the
// labels seen on the PREVIOUS frame: a changed label set appears one frame late
// (never visible for a stable list). Keep tab declaration order stable.
//
// The narrow window below forces the headers to wrap across rows.
//
// STANDALONE: daslang.exe modules/dasImgui/examples/tutorial/wrap_tab_bar.das
// LIVE:       daslang-live modules/dasImgui/examples/tutorial/wrap_tab_bar.das
//
// DRIVE (when running live) — select the "lava" tab (index 2):
//   curl -X POST -d '{"name":"imgui_force_set","args":{"target":"WTB_WIN/WTB_BAR","value":2}}' \
//        localhost:9090/command
// =============================================================================

[export]
def init() {
    live_create_window("dasImgui wrap_tab_bar tutorial", 520, 560)
    live_imgui_init(live_window)
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 1.4
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()

    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    apply_synth_io_override()
    NewFrame()

    SetNextWindowPos(ImVec2(20.0f, 20.0f), ImGuiCond.Always)
    // deliberately narrow so the eight headers wrap onto multiple rows
    SetNextWindowSize(ImVec2(360.0f, 500.0f), ImGuiCond.Always)
    window(WTB_WIN, (text = "wrap_tab_bar tutorial", closable = false,
                     flags = ImGuiWindowFlags.None)) {

        text("Eight categories in a narrow panel — the native TabBar would")
        text("ellipsize or scroll; wrap_tab_bar flows them onto rows.")
        separator()

        wrap_tab_bar(WTB_BAR) {
            wrap_tab_item("physics") {
                text(WTB_B0, (text = "physics — gravity, restitution, drag"))
            }
            wrap_tab_item("camera") {
                text(WTB_B1, (text = "camera — zoom, follow, lookahead"))
            }
            wrap_tab_item("lava") {
                text(WTB_B2, (text = "lava — speed, scale, warp, crust"))
            }
            wrap_tab_item("cinders") {
                text(WTB_B3, (text = "cinders — brightness, density, rise"))
            }
            wrap_tab_item("audio") {
                text(WTB_B4, (text = "audio — master gain, music, sfx"))
            }
            wrap_tab_item("lighting") {
                text(WTB_B5, (text = "lighting — ambient, noise, scale"))
            }
            wrap_tab_item("grid") {
                text(WTB_B6, (text = "grid — size, angle, snap step"))
            }
            wrap_tab_item("misc") {
                text(WTB_B7, (text = "misc — everything else"))
            }
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
