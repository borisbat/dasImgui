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

// =============================================================================
// FEATURE: list_box — unified [container] for BeginListBox/EndListBox. The
//          legacy items-array `[widget] def list_box` was dropped; the modern
//          form is block-arg + user-emitted Selectable rows. Click writes
//          state.value; imgui_set steers it from the test harness.
// SHOWS:   list_box scope with Selectable-driven selection state, custom
//          row rendering (icons in front of names), and dynamic content
//          (filterable item list).
// DRIVE:   curl -X POST -d '{"name":"imgui_set","args":{"target":"MAIN_WIN/LANG","value":3}}' \
//               localhost:9090/command
// STANDALONE: daslang.exe modules/dasImgui/examples/features/list_box.das
// LIVE:       daslang-live modules/dasImgui/examples/features/list_box.das
// =============================================================================

let LANG_NAMES : array<string> <- ["daslang", "C++", "Rust", "Go", "Python", "Lua"]
let LANG_ICONS : array<string> <- ["[D]", "[C]", "[R]", "[G]", "[P]", "[L]"]

[export]
def init() {
    live_create_window("list_box — unified scope form", 720, 540)
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

    SetNextWindowSize(ImVec2(660.0, 480.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "list_box", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        Text("Body emits Selectable rows; click writes LANG.value.")
        Separator()

        list_box(LANG, (text = "Language", size = float2(-1.0f, 180.0f))) {
            for (i in range(length(LANG_NAMES))) {
                let is_sel = (i == LANG.value)
                let row_text = "{LANG_ICONS[i]} {LANG_NAMES[i]}"
                if (Selectable(row_text, is_sel,
                               ImGuiSelectableFlags.None,
                               float2(0.0f, 0.0f))) {
                    LANG.value = i
                }
            }
        }

        Separator()
        var picked = "(none)"
        if (LANG.value >= 0 && LANG.value < length(LANG_NAMES)) {
            picked = LANG_NAMES[LANG.value]
        }
        Text("Picked: {picked} (idx {LANG.value})")
        Text("imgui_set value=N steers next-frame selection.")
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
