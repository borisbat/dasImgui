options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``tree_image_misc.apng`` against
//! ``examples/tutorial/tree_image_misc.das``. Tours two leaf widgets —
//! tree_node_ex (leaf form; caller pairs TreePop) and image (display
//! only; no ClickState).
//!
//! Stage 1 clicks the tree_node_ex header to expand/collapse so the
//! recording shows the open/close transition.

def widget_bbox(var snap : JsonValue?; ident : string) : float4 {
    var b = snap?["globals"]?[ident]?["bbox"]
    return float4(
        b?["x"] ?? 0.0f,
        b?["y"] ?? 0.0f,
        b?["z"] ?? 0.0f,
        b?["w"] ?? 0.0f
    )
}

def widget_center(var snap : JsonValue?; ident : string) : tuple<float; float> {
    let b = widget_bbox(snap, ident)
    return ((b.x + b.z) * 0.5f, (b.y + b.w) * 0.5f)
}

[export]
def main {
    with_recording_app("examples/tutorial/tree_image_misc.das",
                       "tree_image_misc.apng", 35) $(app) {
        let T_TREE = "TI_WIN/TI_TREE"
        let T_IMG  = "TI_WIN/TI_IMG"

        var snap = wait_for_widget(app, T_TREE, 10.0f)
        if (snap == null) {
            panic("{T_TREE} never registered — wrong app running?")
        }
        let p_tree = widget_center(snap, T_TREE)

        //! Initial cursor placement.
        move_to(app, p_tree, 500)
        sleep(SETTLE_MS)

        // ---- Stage 1: tree_node_ex — click to expand ----
        post_command(app, "imgui_click", JV((target = T_TREE)))
        sleep(CLICK_DWELL_MS)
        say(app, "tree_node_ex — leaf form returns the open bool. Caller pairs tree_pop() inside the truthy branch (unless NoTreePushOnOpen). The container form `tree_node` auto-pairs; reach for `_ex` for explicit flag control.", T_TREE)

        //! Re-snapshot after expand so image bbox is current.
        snap = wait_for_widget(app, T_IMG, 5.0f)
        if (snap == null) {
            panic("{T_IMG} never registered after expand")
        }
        let p_img = widget_center(snap, T_IMG)

        // ---- Stage 2: image — display only ----
        move_to(app, p_img, 800)
        sleep(SETTLE_MS)
        say(app, "image — display-only sibling of image_button. ImageState captures size + uv0/uv1 + tint + border for snapshot. For a clickable texture, use image_button (ClickState).", T_IMG)
    }
}
