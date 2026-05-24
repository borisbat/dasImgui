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
// TUTORIAL: collapsing_header — expandable section header with optional X-button.
//
//   collapsing_header(IDENT, (text = "..", closable = bool,
//                             flags = ImGuiTreeNodeFlags....)) { body }
//
// Same shape as tree_node BUT no TreePop pair — ImGui owns the close lifecycle.
// Two distinct gates control whether the body runs:
//
//   1. EXPANDED (chevron) — user toggles via the disclosure arrow. The boost
//      wrapper mirrors this in state.opened (per-frame, from CollapsingHeader's
//      return). pending_open / pending_close (driven by imgui_open / imgui_close)
//      flip the expansion via SetNextItemOpen.
//
//   2. CLOSABLE (X-button) — if closable=true, ImGui adds an X-button that
//      sets state.open=false. While state.open is false the section is hidden
//      entirely (not even a header strip renders). Open-channel flipping needs
//      both gates: pending_open sets state.open back to true AND SetNextItemOpen.
//
// STANDALONE: daslang.exe modules/dasImgui/examples/tutorial/collapsing_header.das
// LIVE:       daslang-live modules/dasImgui/examples/tutorial/collapsing_header.das
//
// DRIVE (when running live):
//   curl -X POST -d '{"name":"imgui_open","args":{"target":"CH_WIN/CLOSABLE_CH"}}' \
//        localhost:9090/command
//   curl -X POST -d '{"name":"imgui_close","args":{"target":"CH_WIN/CLOSABLE_CH"}}' \
//        localhost:9090/command
// =============================================================================

[export]
def init() {
    live_create_window("dasImgui collapsing_header tutorial", 760, 520)
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
    SetNextWindowSize(ImVec2(720.0f, 480.0f), ImGuiCond.Always)
    window(CH_WIN, (text = "collapsing_header tutorial", closable = false,
                    flags = ImGuiWindowFlags.None)) {

        text("Three collapsing_header variants — basic, closable, default-open.")
        separator()

        // ---- A: basic (non-closable) ----
        collapsing_header(BASIC_CH, (text = "Basic header", closable = false,
                                     flags = ImGuiTreeNodeFlags.None)) {
            text("Click the chevron to fold this section.")
            checkbox(BASIC_LIVE, (text = "Receive updates"))
            text("opened = {BASIC_CH.opened}")
        }

        // ---- B: closable (renders an X-button) ----
        collapsing_header(CLOSABLE_CH, (text = "Closable header",
                                        closable = true,
                                        flags = ImGuiTreeNodeFlags.DefaultOpen)) {
            text("X-button on the right of the header strip closes this section.")
            text("Once closed, the whole row disappears — flip back via")
            text("imgui_open against CH_WIN/CLOSABLE_CH.")
            slider_int(VOLUME, (text = "volume"))
        }
        text("CLOSABLE_CH.open = {CLOSABLE_CH.open}, opened = {CLOSABLE_CH.opened}")
        separator()

        // ---- C: DefaultOpen flag (chevron already down on first frame) ----
        collapsing_header(STARTUP_CH, (text = "Starts open (DefaultOpen flag)",
                                       closable = false,
                                       flags = ImGuiTreeNodeFlags.DefaultOpen)) {
            text(STARTUP_HINT, (text = "ImGuiTreeNodeFlags.DefaultOpen makes the chevron expanded"))
            text("on first render — subsequent frames respect user input.")
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
