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
require imgui/imgui_boost_runtime
require imgui/imgui_boost_v2
require imgui/imgui_widgets_builtin

// Phase 0a v0 — globals pre-declared manually. Once the macro's emit-on-first-use
// path is sorted, these can come back out and live-emit from the call_macro.
var SAVE_BTN : ButtonState
var SPEED   : SliderStateInt = SliderStateInt(value = 5, init_value = 5, bounds = (0, 10))
var VOLUME  : SliderStateFloat = SliderStateFloat(value = 0.5f, init_value = 0.5f, bounds = (0.0f, 1.0f))

// =============================================================================
// Phase 0a — define_widget core: declarative widgets via [widget].
// Side-by-side with phase00_button/, this demo trades ~220 lines of
// hand-rolled state + render + live-command code for ~30 lines of widget
// invocations. The macros (in widgets/imgui_boost.das) handle global
// emission, prelude/postlude wrapping, and per-kind dispatcher registration.
//
// Drive it from a second terminal:
//   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command
//   curl -X POST -d '{"name":"imgui_click","args":{"target":"SAVE_BTN"}}' \
//        localhost:9090/command
//   curl -X POST -d '{"name":"imgui_set","args":{"target":"SPEED","value":7}}' \
//        localhost:9090/command
// =============================================================================

def init_imgui() {
    CreateContext(null)
    var io & = unsafe(GetIO())
    io.FontGlobalScale = 2.0
    StyleColorsDark(null)
    ImGui_ImplGlfw_InitForOpenGL(live_window, true)
    ImGui_ImplOpenGL3_Init("#version 330")
}

def shutdown_imgui() {
    ImGui_ImplOpenGL3_Shutdown()
    ImGui_ImplGlfw_Shutdown()
    DestroyContext(null)
}

[export]
def init() {
    live_create_window("Phase 0a — define_widget", 800, 600)
    init_imgui()
}

[export]
def update() {
    if (!live_begin_frame()) {
        return
    }
    begin_frame()  // imgui_boost_runtime: clears registry, bumps frame counter

    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(720.0, 320.0), ImGuiCond.Always)
    if (Begin("Phase 0a", null, ImGuiWindowFlags.None)) {
        Text("define_widget demo — every widget below comes from a [widget] decl.")

        // Button — return form, identifier becomes the daslang global SAVE_BTN.
        if (button(SAVE_BTN, [text = "Save"])) {
            print("save clicked, count={SAVE_BTN.click_count}\n")
        }
        Text("save clicks: {SAVE_BTN.click_count}")

        // Slider int — emits SliderStateInt SPEED at module scope.
        slider_int(SPEED, [text = "Speed (int)"])
        Text("speed = {SPEED.value}")

        // Slider float — emits SliderStateFloat VOLUME at module scope.
        slider(VOLUME, [text = "Volume (float)"])
        Text("volume = {VOLUME.value}")
    }
    End()

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
    shutdown_imgui()
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
