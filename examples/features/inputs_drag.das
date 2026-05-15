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
// FEATURE: inputs_drag — every Phase 0b.2 Drag* widget in one window.
// SHOWS:   DragFloat / DragFloat2 / DragFloat3 / DragFloat4
//          DragInt / DragInt2 / DragInt3 / DragInt4
//          DragFloatRange2 / DragIntRange2
// DRIVE:   curl -X POST -d '{"name":"imgui_snapshot"}' localhost:9090/command
//          curl -X POST -d '{"name":"imgui_set","args":{"target":"MAIN_WIN/OPACITY","value":0.5}}' \
//               localhost:9090/command
//          curl -X POST -d '{"name":"imgui_set","args":{"target":"MAIN_WIN/SCALE_XY","value":[2.0, 1.5]}}' \
//               localhost:9090/command
//          curl -X POST -d '{"name":"imgui_set","args":{"target":"MAIN_WIN/PRICE","value":[5, 12]}}' \
//               localhost:9090/command
// STANDALONE: daslang.exe modules/dasImgui/examples/features/inputs_drag.das
// LIVE:       daslang-live modules/dasImgui/examples/features/inputs_drag.das
// =============================================================================

[export]
def init() {
    live_create_window("Phase 0b.2 — drag inputs", 800, 700)
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

    SetNextWindowSize(ImVec2(720.0, 660.0), ImGuiCond.Always)
    window(MAIN_WIN, (text = "Drag inputs — phase 0b.2", closable = false,
                      flags = ImGuiWindowFlags.None)) {
        // ----- Float scalars -----
        // Bounds set once-per-frame from source; assignment is idempotent.
        // `speed` / `format` / `flags` are per-call args (defaults 1.0f/"%.3f"/None).
        text("Float scalars")
        separator()
        OPACITY.bounds = (0.0f, 1.0f)
        drag_float(OPACITY, (text = "Opacity", speed = 0.01f))
        text("opacity = {OPACITY.value}")

        // ----- Float vectors -----
        text("Float vectors")
        separator()
        SCALE_XY.bounds = (0.0f, 4.0f)
        drag_float2(SCALE_XY, (text = "Scale XY", speed = 0.05f))
        text("scale = ({SCALE_XY.value.x}, {SCALE_XY.value.y})")

        TINT_RGB.bounds = (0.0f, 1.0f)
        drag_float3(TINT_RGB, (text = "Tint RGB", speed = 0.01f))
        text("tint = ({TINT_RGB.value.x}, {TINT_RGB.value.y}, {TINT_RGB.value.z})")

        TINT_RGBA.bounds = (0.0f, 1.0f)
        drag_float4(TINT_RGBA, (text = "Tint RGBA", speed = 0.01f))
        text("tint_a = {TINT_RGBA.value.w}")

        spacing()

        // ----- Int scalars -----
        text("Int scalars")
        separator()
        SCORE.bounds = (0, 100)
        drag_int(SCORE, (text = "Score"))
        text("score = {SCORE.value}")

        // ----- Int vectors -----
        text("Int vectors")
        separator()
        TILE_XY.bounds = (-32, 32)
        drag_int2(TILE_XY, (text = "Tile XY"))
        text("tile = ({TILE_XY.value.x}, {TILE_XY.value.y})")

        VOXEL_XYZ.bounds = (-16, 16)
        drag_int3(VOXEL_XYZ, (text = "Voxel XYZ"))
        text("voxel = ({VOXEL_XYZ.value.x}, {VOXEL_XYZ.value.y}, {VOXEL_XYZ.value.z})")

        RECT_LTRB.bounds = (0, 256)
        drag_int4(RECT_LTRB, (text = "Rect LTRB"))
        text("rect_w = {RECT_LTRB.value.z - RECT_LTRB.value.x}")

        spacing()

        // ----- Range pairs -----
        text("Range pairs")
        separator()
        SPEED_BAND.bounds = (0.0f, 100.0f)
        drag_float_range2(SPEED_BAND, (text = "Speed band", speed = 0.5f))
        text("speed range = [{SPEED_BAND.value.x}, {SPEED_BAND.value.y}]")

        PRICE.bounds = (0, 50)
        drag_int_range2(PRICE, (text = "Price"))
        text("price = [{PRICE.value.x}, {PRICE.value.y}]")
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
