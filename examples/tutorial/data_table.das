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
require imgui/imgui_table_builtin
require imgui/imgui_visual_aids

// =============================================================================
// TUTORIAL: data_table — boost container for ImGui's tables API.
//
// `BeginTable` / `EndTable` and the body-internal cursor calls
// (TableSetupColumn, TableHeadersRow, TableNextRow, TableSetColumnIndex,
// TableNextColumn) live behind one container + six snake_case pass-throughs
// in `imgui/imgui_table_builtin`. The container is named `data_table`
// (not `table`, which is a daslang reserved keyword for `table<K;V>`).
//
//   data_table(MY_TABLE, (text = "##split", columns = 3, flags = ...,
//                          outer_size = float2(0,0), inner_width = 0.0f)) {
//       table_setup_column("Name")
//       table_setup_column("Type")
//       table_setup_column("Value")
//       table_headers_row()
//       for (row in rows) {
//           table_next_row()
//           table_set_column_index(0); text(NAME[row], (text = ...))
//           table_set_column_index(1); text(TYPE[row], (text = ...))
//           table_set_column_index(2); text(VAL[row], (text = ...))
//       }
//   }
//
// `TableState` echoes per-call config (columns / flags / outer_size /
// inner_width). Sort-spec capture, multi-select hand-off, frozen-row
// indicators belong to a future `tables.das` port and extend the state
// additively.
//
// STANDALONE: daslang.exe modules/dasImgui/examples/tutorial/data_table.das
// LIVE:       daslang-live modules/dasImgui/examples/tutorial/data_table.das
// =============================================================================

struct private Row {
    name : string
    kind : string
    value : string
}

var private ROWS : array<Row>

[init]
def seed_rows() {
    ROWS <- [
        Row(name = "alpha", kind = "int", value = "42"),
        Row(name = "beta", kind = "float", value = "3.14"),
        Row(name = "gamma", kind = "string", value = "hello"),
        Row(name = "delta", kind = "bool", value = "true"),
        Row(name = "epsilon", kind = "int", value = "-7"),
        Row(name = "zeta", kind = "float", value = "0.001")
    ]
}

var DT_NAME : table<int; NarrativeState>
var DT_KIND : table<int; NarrativeState>
var DT_VAL : table<int; NarrativeState>

[export]
def init() {
    live_create_window("dasImgui data_table tutorial", 720, 460)
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

    SetNextWindowPos(ImVec2(30.0f, 30.0f), ImGuiCond.FirstUseEver)
    SetNextWindowSize(ImVec2(640.0f, 380.0f), ImGuiCond.FirstUseEver)
    window(DT_WIN, (text = "data_table", closable = false,
                    flags = ImGuiWindowFlags.None)) {
        text(DT_HEADER, (text = "Three columns over six rows — frozen header."))

        let tflags = (int(ImGuiTableFlags.BordersOuter) |
                      int(ImGuiTableFlags.RowBg) |
                      int(ImGuiTableFlags.Resizable) |
                      int(ImGuiTableFlags.ScrollY))
        data_table(DT_TABLE, (text = "##rows", columns = 3,
                              flags = unsafe(reinterpret<ImGuiTableFlags>(tflags)),
                              outer_size = float2(0.0f, 0.0f),
                              inner_width = 0.0f)) {
            table_setup_scroll_freeze(0, 1)
            table_setup_column("Name")
            table_setup_column("Type")
            table_setup_column("Value")
            table_headers_row()
            for (i in range(length(ROWS))) {
                table_next_row()
                table_set_column_index(0)
                text(DT_NAME[i], (text = ROWS[i].name))
                table_set_column_index(1)
                text(DT_KIND[i], (text = ROWS[i].kind))
                table_set_column_index(2)
                text(DT_VAL[i], (text = ROWS[i].value))
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
