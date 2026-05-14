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

// =============================================================================
// FEATURE: edit_external_scalars — [edit_widget] rail, scalar overloads.
// SHOWS:   edit_slider_{float,int}, edit_drag_{float,int}, edit_input_{float,int},
//          edit_input_double — all take a caller-owned `T?` pointer. No state
//          struct, no auto-emit; payload is `{value: T}`. Caller picks
//          safe_addr(local) (when the pointee is a plain local/global) or
//          unsafe(addr(struct.field)) for struct-field access. Required
//          `id="…"` literal at the call site keys the telemetry path —
//          missing id fails at compile time.
// DRIVE:   curl -X POST -d '{"name":"imgui_set","args":{"target":"MAIN_WIN/SLIDER_F","value":0.9}}' \
//              localhost:9090/command
//          curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command \
//              | jq '.globals."MAIN_WIN/SLIDER_F".payload.value'
// STANDALONE: daslang.exe modules/dasImgui/examples/features/edit_external_scalars.das
// LIVE:       daslang-live modules/dasImgui/examples/features/edit_external_scalars.das
// =============================================================================

var private g_slider_f : float = 0.5f
var private g_slider_i : int = 50
var private g_drag_f : float = 1.0f
var private g_drag_i : int = 7
var private g_input_f : float = 3.14f
var private g_input_i : int = 42
var private g_input_d : double = 6.28lf

[export]
def init() {
    live_create_window("edit_external_scalars — boost v2 §3.7", 760, 480)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(720.0, 420.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "edit_* scalars", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text(LEAD, (text = "Each row reads/writes through safe_addr(global). imgui_set updates the pointee directly."))
        edit_slider_float(safe_addr(g_slider_f), (id = "SLIDER_F",
                                                  text = "slider float",
                                                  v_min = 0.0f, v_max = 1.0f))
        edit_slider_int(safe_addr(g_slider_i), (id = "SLIDER_I",
                                                text = "slider int",
                                                v_min = 0, v_max = 100))
        edit_drag_float(safe_addr(g_drag_f), (id = "DRAG_F",
                                              text = "drag float", speed = 0.1f))
        edit_drag_int(safe_addr(g_drag_i), (id = "DRAG_I",
                                            text = "drag int", speed = 1.0f))
        edit_input_float(safe_addr(g_input_f), (id = "INPUT_F",
                                                text = "input float", step = 0.1f))
        edit_input_int(safe_addr(g_input_i), (id = "INPUT_I",
                                              text = "input int", step = 1))
        edit_input_double(safe_addr(g_input_d), (id = "INPUT_D",
                                                 text = "input double", step = 0.01lf))
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
