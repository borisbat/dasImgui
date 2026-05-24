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
        // tree_node and window containers finalize without a bbox, so
        // anchor every move/narrate target at a real leaf widget. See
        // PR #67 Copilot round 1.
        let T_PHYSICS_PATH = "TN_WIN/PHYSICS_TREE"
        let T_PHYSICS_LEAF = "TN_WIN/PHYSICS_TREE/PHYSICS_GRAVITY"
        let T_RENDER_PATH = "TN_WIN/RENDER_TREE"
        let T_FOV_LEAF = "TN_WIN/RENDER_TREE/CAMERA_SUBTREE/RENDER_FOV"
        let T_ASSETS_LEAF = "TN_WIN/ASSETS_TREE/ASSETS_HINT"

        // wait_for_widget gates on existence; wait_for_render passes
        // through for absent paths.
        var snap = wait_for_widget(app, T_PHYSICS_LEAF, 10.0f)
        if (snap == null) {
            panic("{T_PHYSICS_LEAF} never registered — wrong app running?")
        }
        let p_physics = widget_center(snap, T_PHYSICS_LEAF)

        //! Initial cursor placement.
        move_to(app, p_physics, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: narrate PHYSICS (DefaultOpen) ----
        move_to(app, p_physics, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "tree_node(IDENT, (text, flags)) — block-arg container. DefaultOpen flag expanded the chevron from frame 1; opened mirrors TreeNodeEx's return.",
            target = T_PHYSICS_LEAF,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: close PHYSICS via imgui_close ----
        post_command(app, "imgui_close", JV((target = T_PHYSICS_PATH)))
        sleep(TOGGLE_DWELL_MS)
        // PHYSICS_GRAVITY is gone now that PHYSICS_TREE is collapsed —
        // narrate against ASSETS_HINT (always present) to mention the gating.
        post_command(app, "imgui_narrate", JV((
            text = "imgui_close routes through pending_close — next frame SetNextItemOpen(false) overrides ImGui's stored state. opened flips false; the body block stops running.",
            target = T_ASSETS_LEAF,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
        post_command(app, "imgui_open", JV((target = T_PHYSICS_PATH)))
        sleep(1500u)

        // ---- Stage 3: open RENDER, then narrate nesting ----
        post_command(app, "imgui_open", JV((target = T_RENDER_PATH)))
        sleep(TOGGLE_DWELL_MS)
        // Re-snap to pick up the now-rendered RENDER children.
        var snap2 = wait_for_widget(app, T_FOV_LEAF, 5.0f)
        if (snap2 != null) {
            let p_fov = widget_center(snap2, T_FOV_LEAF)
            move_to(app, p_fov, 700)
            sleep(SETTLE_MS)
        }
        post_command(app, "imgui_narrate", JV((
            text = "Nested tree_nodes compose freely. Camera subtree's slider registers at TN_WIN/RENDER_TREE/CAMERA_SUBTREE/RENDER_FOV — three-deep path.",
            target = T_FOV_LEAF,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 4: ASSETS (OpenOnArrow) ----
        // Re-snap because the layout has shifted (RENDER_TREE is now open,
        // pushing ASSETS_TREE down). ASSETS_HINT exists from frame 1 because
        // the tutorial source declares ASSETS_TREE with DefaultOpen.
        var p_assets = widget_center(snap, T_ASSETS_LEAF)
        var snap_assets = wait_for_widget(app, T_ASSETS_LEAF, 5.0f)
        if (snap_assets != null) {
            p_assets = widget_center(snap_assets, T_ASSETS_LEAF)
        }
        move_to(app, p_assets, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "OpenOnArrow flag — only the chevron click toggles; clicking the LABEL doesn't expand. Useful for selectable-row trees where the label is the selection.",
            target = T_ASSETS_LEAF,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
    }
}
