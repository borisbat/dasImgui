options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Integration smoke for `popup_context_window` — right-click context menu
//! over the host window. Verifies kind, right_click opens the popup, menu
//! items register at container-nested paths, and selecting items updates
//! the LAST_PICK display state.

let FEATURE = "modules/dasImgui/examples/features/popup_context_window.das"

[test]
def test_popup_context_window_smoke(t : T?) {
    with_imgui_app(FEATURE) $(d) {
        var snap = wait_for_widget(d, "MAIN_WIN/CTX", 15.0f)
        t |> success(snap != null, "CTX container registers")
        if (snap == null) return

        let ctx = find_widget(snap, "MAIN_WIN/CTX")
        t |> equal(ctx?["kind"] ?? "", "popup_context_window",
                   "CTX.kind == 'popup_context_window'")

        // STATUS reflects no pick yet.
        t |> equal(widget_payload_field(snap, "MAIN_WIN/STATUS", "value") ?? "",
                   "last pick: (none yet)",
                   "STATUS shows '(none yet)' initially")

        // Body widgets do NOT register while the popup is closed (per
        // imgui_containers_builtin's stateless_finalize gated on im_open).
        t |> success(!widget_exists(snap, "MAIN_WIN/CTX/ITEM_NEW"),
                     "ITEM_NEW absent while popup closed")

        // Right-click somewhere in the window body. playwright's right_click
        // helper falls through L1 with button hardcoded to 0 (left), so we
        // use the raw imgui_mouse_* bypass with button=1 explicitly. Anchor
        // at LEAD's bbox center — guaranteed body-interior, not title bar.
        let lead_bbox = find_widget(snap, "MAIN_WIN/LEAD")?["bbox"]
        let lead_x = ((lead_bbox?["x"] ?? 0.0f) + (lead_bbox?["z"] ?? 0.0f)) * 0.5f
        let lead_y = ((lead_bbox?["y"] ?? 0.0f) + (lead_bbox?["w"] ?? 0.0f)) * 0.5f
        post_command(d, "imgui_mouse_pos", JV((x = lead_x, y = lead_y)))
        post_command(d, "imgui_mouse_click", JV((button = 1, action = "press")))
        post_command(d, "imgui_mouse_click", JV((button = 1, action = "release")))
        t |> success(wait_for_mouse_idle(d, 4.0f), "RMB timeline drains")
        var snap_open = wait_for_widget(d, "MAIN_WIN/CTX/ITEM_NEW", 5.0f)
        t |> success(snap_open != null, "ITEM_NEW registers after right-click")
        if (snap_open == null) return

        // Pick "New" — ImGui auto-closes the popup on mouse-move-outside, so
        // a path-resolved click() can land outside the popup window. Use
        // raw imgui_mouse_* at ITEM_NEW's bbox center (still inside popup
        // since the cursor stays there).
        let new_bbox = find_widget(snap_open, "MAIN_WIN/CTX/ITEM_NEW")?["bbox"]
        let new_x = ((new_bbox?["x"] ?? 0.0f) + (new_bbox?["z"] ?? 0.0f)) * 0.5f
        let new_y = ((new_bbox?["y"] ?? 0.0f) + (new_bbox?["w"] ?? 0.0f)) * 0.5f
        post_command(d, "imgui_mouse_pos", JV((x = new_x, y = new_y)))
        post_command(d, "imgui_mouse_click", JV((button = 0, action = "press")))
        post_command(d, "imgui_mouse_click", JV((button = 0, action = "release")))
        t |> success(wait_for_mouse_idle(d, 4.0f), "LMB on ITEM_NEW drains")
        t |> success(wait_for_string_value(d, "MAIN_WIN/STATUS", "value",
                                           "last pick: New", 300),
                     "STATUS reflects 'New' after menu pick")

        // Re-open + pick "Quit" — verifies the popup can be re-opened.
        post_command(d, "imgui_mouse_pos", JV((x = lead_x, y = lead_y)))
        post_command(d, "imgui_mouse_click", JV((button = 1, action = "press")))
        post_command(d, "imgui_mouse_click", JV((button = 1, action = "release")))
        t |> success(wait_for_mouse_idle(d, 4.0f), "second RMB timeline drains")
        var snap_open2 = wait_for_widget(d, "MAIN_WIN/CTX/ITEM_QUIT", 5.0f)
        t |> success(snap_open2 != null, "ITEM_QUIT registers on re-open")
        if (snap_open2 == null) return
        let quit_bbox = find_widget(snap_open2, "MAIN_WIN/CTX/ITEM_QUIT")?["bbox"]
        let quit_x = ((quit_bbox?["x"] ?? 0.0f) + (quit_bbox?["z"] ?? 0.0f)) * 0.5f
        let quit_y = ((quit_bbox?["y"] ?? 0.0f) + (quit_bbox?["w"] ?? 0.0f)) * 0.5f
        post_command(d, "imgui_mouse_pos", JV((x = quit_x, y = quit_y)))
        post_command(d, "imgui_mouse_click", JV((button = 0, action = "press")))
        post_command(d, "imgui_mouse_click", JV((button = 0, action = "release")))
        t |> success(wait_for_mouse_idle(d, 4.0f), "LMB on ITEM_QUIT drains")
        t |> success(wait_for_string_value(d, "MAIN_WIN/STATUS", "value",
                                           "last pick: Quit", 300),
                     "STATUS reflects 'Quit' after second menu pick")
    }
}
