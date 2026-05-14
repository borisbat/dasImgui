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
// FEATURE: edit_external_combo — combo dropdown on external int? pointer.
// SHOWS:   edit_combo(safe_addr(idx), (id=…, items <- ARR)) — passes the
//          items as `array<string>`; the C-side reads via the array-of-
//          C-string-pointers Combo overload (no per-frame zero-separated
//          buffer packing — daslang `string` already carries the trailing
//          null). Payload is {value: N} where N is the selected index.
// DRIVE:   curl -X POST -d '{"name":"imgui_set","args":{"target":"MAIN_WIN/COMBO_THEME","value":2}}' \
//              localhost:9090/command
// STANDALONE: daslang.exe modules/dasImgui/examples/features/edit_external_combo.das
// LIVE:       daslang-live modules/dasImgui/examples/features/edit_external_combo.das
// =============================================================================

var private g_theme_idx : int = 1
var private g_difficulty_idx : int = 2

let private g_themes : array<string> <- ["Light", "Dark", "Solarized", "Forge"]
let private g_difficulties : array<string> <- ["Easy", "Normal", "Hard", "Insane"]

[export]
def init() {
    live_create_window("edit_external_combo — boost v2 §3.7", 720, 360)
    live_imgui_init(live_window)
}

[export]
def update() {
    if (!live_begin_frame()) return
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    NewFrame()

    SetNextWindowSize(ImVec2(680.0, 300.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "edit_combo", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        text(LEAD, (text = "Two combos against caller-owned int? indices."))
        edit_combo(safe_addr(g_theme_idx), (id = "COMBO_THEME",
                                            text = "theme",
                                            items <- g_themes))
        text(STATUS_THEME, (text = "selected theme idx = {g_theme_idx} ({g_themes[g_theme_idx]})"))
        separator(SEP)
        edit_combo(safe_addr(g_difficulty_idx), (id = "COMBO_DIFFICULTY",
                                                 text = "difficulty",
                                                 items <- g_difficulties,
                                                 popup_max_height_in_items = 3))
        text(STATUS_DIFF, (text = "selected difficulty idx = {g_difficulty_idx}"))
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
