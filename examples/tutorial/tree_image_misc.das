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
require imgui/imgui_layout_builtin
require imgui/imgui_visual_aids

// =============================================================================
// TUTORIAL: tree_node_ex + image — two widgets the container-shaped variants
// don't cover.
//
//   tree_node_ex(IDENT, (text = "..", flags = ...))     — leaf form. Returns
//                                                          the open bool;
//                                                          caller pairs
//                                                          TreePop() when
//                                                          needed (when no
//                                                          NoTreePushOnOpen
//                                                          flag).
//
//   image(IDENT, (texture = tex_id, size = ...,         — display widget.
//                 uv0 = .., uv1 = .., tint_col = ..,      No state-tracked
//                 border_col = ..))                       click / hover; cf.
//                                                          image_button for
//                                                          the click trigger.
//
// tree_node_ex is the explicit-control sibling of `tree_node` (the
// container). Use it when you need the open/closed bool to gate sibling
// work, OR when you want NoTreePushOnOpen / Bullet / Leaf flags that
// the container form doesn't surface cleanly.
//
// image is the display-only sibling of image_button — no ClickState, no
// frame padding, no click semantics.
//
// STANDALONE: daslang.exe modules/dasImgui/examples/tutorial/tree_image_misc.das
// LIVE:       daslang-live modules/dasImgui/examples/tutorial/tree_image_misc.das
// =============================================================================

[export]
def init() {
    live_create_window("dasImgui tree_node_ex + image tutorial", 800, 660)
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
    SetNextWindowSize(ImVec2(760.0f, 620.0f), ImGuiCond.Always)
    window(TI_WIN, (text = "tree_node_ex + image tutorial", closable = false,
                    flags = ImGuiWindowFlags.None)) {

        text("Two leaf widgets the container-shaped variants don't cover.")
        text(TI_HINT, (text = "tree_node_ex returns the bool; image is display-only (no click)."))
        separator()

        // ---- Stage 1: tree_node_ex — leaf form, caller controls TreePop ----
        text("tree_node_ex (leaf form — caller pairs TreePop):")
        if (tree_node_ex(TI_TREE, (text = "Group", flags = ImGuiTreeNodeFlags.None))) {
            text("  child A")
            text("  child B")
            text("  child C")
            tree_pop()
        }
        spacing()

        // ---- Stage 2: image — display, no click ----
        text("image (display widget — paints a texture; no ClickState):")
        let io & = unsafe(GetIO())
        let font_tex = io.Fonts.TexID
        if (font_tex != null) {
            image(TI_IMG, (texture = font_tex,
                           size = float2(128.0f, 128.0f),
                           uv0 = float2(0.0f, 0.0f),
                           uv1 = float2(1.0f, 1.0f),
                           tint_col = float4(1.0f, 1.0f, 1.0f, 1.0f),
                           border_col = float4(0.6f, 0.6f, 0.6f, 1.0f)))
            text("font atlas at 128x128 — no click, no padding; cf image_button.")
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
