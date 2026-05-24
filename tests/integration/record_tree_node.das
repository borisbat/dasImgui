options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``tree_node.apng`` against
//! ``examples/tutorial/tree_node.das``. Tours DefaultOpen, nested
//! tree_nodes, and OpenOnArrow click semantics.

let NARRATE_FRAMES = 240        //! 4.0s visible at 60 fps app
let READ_MS    = 5000u          //! 5s read window
let SETTLE_MS  = 1500u          //! 1.5s cursor settle
let TOGGLE_DWELL_MS = 2200u     //! 2.2s post-toggle dwell

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
    with_recording_app("examples/tutorial/tree_node.das",
                       "tree_node.apng", 60) $(app) {
        let T_PHYSICS = "TN_WIN/PHYSICS_TREE"
        let T_RENDER = "TN_WIN/RENDER_TREE"
        let T_ASSETS = "TN_WIN/ASSETS_TREE"
        let T_WIN = "TN_WIN"

        var snap = wait_for_render(app, T_PHYSICS, 10.0f)
        if (snap == null) {
            panic("{T_PHYSICS} never rendered — wrong app running?")
        }
        let p_physics = widget_center(snap, T_PHYSICS)
        let p_render = widget_center(snap, T_RENDER)
        let p_assets = widget_center(snap, T_ASSETS)
        let p_win = widget_center(snap, T_WIN)

        //! Initial cursor placement.
        move_to(app, p_win, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: narrate PHYSICS (DefaultOpen) ----
        move_to(app, p_physics, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "tree_node(IDENT, (text, flags)) — block-arg container. DefaultOpen flag expanded the chevron from frame 1; opened mirrors TreeNodeEx's return.",
            target = T_PHYSICS,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: close PHYSICS via imgui_close ----
        post_command(app, "imgui_close", JV((target = T_PHYSICS)))
        sleep(TOGGLE_DWELL_MS)
        post_command(app, "imgui_narrate", JV((
            text = "imgui_close routes through pending_close — next frame SetNextItemOpen(false) overrides ImGui's stored state. opened flips false; the body block stops running.",
            target = T_PHYSICS,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
        post_command(app, "imgui_open", JV((target = T_PHYSICS)))
        sleep(1500u)

        // ---- Stage 3: open RENDER, then narrate nesting ----
        post_command(app, "imgui_open", JV((target = T_RENDER)))
        sleep(TOGGLE_DWELL_MS)
        move_to(app, p_render, 700)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "Nested tree_nodes compose freely. Camera subtree's slider registers at TN_WIN/RENDER_TREE/CAMERA_SUBTREE/RENDER_FOV — three-deep path.",
            target = T_RENDER,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 4: ASSETS (OpenOnArrow) ----
        move_to(app, p_assets, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "OpenOnArrow flag — only the chevron click toggles; clicking the LABEL doesn't expand. Useful for selectable-row trees where the label is the selection.",
            target = T_ASSETS,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
    }
}
