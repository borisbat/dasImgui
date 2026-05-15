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

// =============================================================================
// FEATURE: drag_drop — [container]s drag_drop_source + drag_drop_target.
//          Both gate their body on ImGui's internal drag-drop state machine.
//          Bodies call raw SetDragDropPayload / AcceptDragDropPayload —
//          payload data is caller-owned and crosses widget boundaries.
// SHOWS:   drag SOURCE_BTN onto TARGET_BTN; TARGET_BTN's body accepts the
//          "MY_INT" payload and writes it into RECEIVED. DROP_COUNT
//          increments on each successful release-over-target.
// STANDALONE: daslang.exe modules/dasImgui/examples/features/drag_drop.das
// LIVE:       daslang-live modules/dasImgui/examples/features/drag_drop.das
// =============================================================================

var PAYLOAD_VALUE : int = 42
var RECEIVED : int = 0
var DROP_COUNT : int = 0

[export]
def init() {
    live_create_window("drag_drop — source + target", 720, 480)
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
    window(MAIN_WIN, (text = "drag_drop", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text("Drag the SOURCE button onto the TARGET button.")
        separator()

        // Source: a normal button. Body runs only on active drag.
        button(SOURCE_BTN, (text = "SOURCE"))
        drag_drop_source(SOURCE_DD, (flags = ImGuiDragDropFlags.None)) {
            unsafe {
                SetDragDropPayload("MY_INT", addr(PAYLOAD_VALUE),
                                   uint64(typeinfo sizeof(PAYLOAD_VALUE)),
                                   ImGuiCond.Once)
            }
            text("Dragging int: {PAYLOAD_VALUE}")
        }

        // 40 px gap between the source and target buttons.
        same_line((spacing = 40.0f))

        // Target: a normal button. Body runs only when payload-bearing drag hovers.
        button(TARGET_BTN, (text = "TARGET"))
        drag_drop_target(TARGET_DD) {
            let payload = AcceptDragDropPayload("MY_INT", ImGuiDragDropFlags.None)
            if (payload != null) {
                unsafe {
                    RECEIVED = (reinterpret<int? const>(payload.Data))[0]
                }
                DROP_COUNT++
            }
        }

        separator()
        text("Source payload value: {PAYLOAD_VALUE}")
        text("Target received value: {RECEIVED}")
        text("Drops accepted: {DROP_COUNT}")
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
