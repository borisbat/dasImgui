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
// FEATURE: inputs_choice — combo (items-array, single-call) + list_box
//          (Begin/End + Selectable, unified block-arg form). list_box was
//          unified onto BeginListBox/EndListBox in the boost scope-wrappers
//          pass; body emits per-item Selectables, click writes state.value.
// SHOWS:   combo (items-array sugar) / list_box (block-arg + Selectable)
// DRIVE:   curl -X POST -d '{"name":"imgui_set","args":{"target":"MAIN_WIN/FRUIT","value":2}}' \
//               localhost:9090/command
//          curl -X POST -d '{"name":"imgui_set","args":{"target":"MAIN_WIN/SHIRT_SIZE","value":1}}' \
//               localhost:9090/command
// STANDALONE: daslang.exe modules/dasImgui/examples/features/inputs_choice.das
// LIVE:       daslang-live modules/dasImgui/examples/features/inputs_choice.das
//
// NOT YET COVERED HERE:
//   - BeginCombo/EndCombo (block-arg manual loop) → combo_select container
//   - _builtin_Combo (callback-getter)            → 0b.4 ABI shim
// =============================================================================

let SHIRT_NAMES : array<string> <- ["XS", "S", "M", "L", "XL", "XXL"]
var SHIRT_ROW : table<int; ClickState>

[export]
def init() {
    live_create_window("Phase 0b.2 — choice inputs", 720, 500)
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

    SetNextWindowSize(ImVec2(660.0, 460.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "Choice inputs — phase 0b.2", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text("Combo (dropdown selector)")
        separator()

        combo(FRUIT, (text = "Fruit",
                      items <- ["Apple", "Banana", "Cherry", "Durian", "Elderberry"]))
        text("fruit index = {FRUIT.value}")

        // popup_max_height_in_items caps the dropdown height — useful for long lists.
        combo(WEEKDAY, (text = "Weekday",
                        items <- ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
                        popup_max_height_in_items = 4))
        text("weekday index = {WEEKDAY.value}")

        spacing()
        text("ListBox (always-open scrollable list)")
        separator()

        list_box(SHIRT_SIZE, (text = "Shirt size",
                              size = float2(0.0f, 0.0f))) {
            for (i in range(length(SHIRT_NAMES))) {
                let is_sel = (i == SHIRT_SIZE.value)
                if (selectable_label(SHIRT_ROW[i], SHIRT_NAMES[i], is_sel)) {
                    SHIRT_SIZE.value = i
                }
            }
        }
        text("shirt size index = {SHIRT_SIZE.value}")

        spacing()
        text("imgui_set with target=MAIN_WIN/FRUIT, value=N jumps to N-th item next frame")
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
    //! Standalone entrypoint. daslang-live drives init/update/shutdown
    //! directly and ignores main(); plain `daslang.exe <file>` runs this loop.
    init()
    while (!exit_requested()) {
        update()
    }
    shutdown()
}
