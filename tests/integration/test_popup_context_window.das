options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Integration smoke for `popup_context_window` — right-click context menu
//! over the host window. Verifies kind, raw RMB synth opens the popup, menu
//! items register at container-nested paths, and selecting items updates
//! the LAST_PICK display state.
//!
//! Why raw synth and not `right_click()`: `right_click()` routes through the
//! `imgui_click` L1 coroutine which writes raw `io.AddMousePosEvent`. Once
//! any prior `imgui_mouse_pos` has flipped `synth_cursor_owned=true`, the
//! per-frame `apply_synth_io_override` re-asserts the stale synth cursor
//! position and races the coroutine's pos events. On the second
//! right_click(LEAD) the synth pos still points at ITEM_NEW (from the
//! previous menu pick's mouse_pos), and the cursor lands somewhere between
//! LEAD and ITEM_NEW — popup opens at the wrong place, ITEM_QUIT bbox
//! shifts, hover never establishes. Using raw synth for both popup-open
//! and menu-pick keeps everything in one pathway with no race.

let FEATURE = "modules/dasImgui/examples/features/popup_context_window.das"

def rmb_release_at(d : ImguiApp; x, y : float) {
    //! Raw synth right-click sequence at (x, y). Stays in the synth pathway
    //! so subsequent calls don't race the coroutine.
    post_command(d, "imgui_mouse_pos", JV((x = x, y = y)))
    post_command(d, "imgui_mouse_click", JV((button = 1, action = "press")))
    post_command(d, "imgui_mouse_click", JV((button = 1, action = "release")))
    wait_for_mouse_idle(d, 4.0f)
}

def lmb_release_at(d : ImguiApp; x, y : float) {
    //! Raw synth left-click sequence at (x, y), same pathway as rmb_release_at.
    post_command(d, "imgui_mouse_pos", JV((x = x, y = y)))
    post_command(d, "imgui_mouse_click", JV((button = 0, action = "press")))
    post_command(d, "imgui_mouse_click", JV((button = 0, action = "release")))
    wait_for_mouse_idle(d, 4.0f)
}

def bbox_center(var snap : JsonValue?; ident : string) : tuple<float; float> {
    let bb : JsonValue? = find_widget(snap, ident)?["bbox"]
    return (((bb?["x"] ?? 0.0f) + (bb?["z"] ?? 0.0f)) * 0.5f,
            ((bb?["y"] ?? 0.0f) + (bb?["w"] ?? 0.0f)) * 0.5f)
}

[test]
def test_popup_context_window_smoke(t : T?) {
    with_imgui_app(FEATURE) $(d) {
        var snap = wait_for_widget(d, "MAIN_WIN/CTX", 15.0f)
        t |> success(snap != null, "CTX container registers")
        if (snap == null) return

        let ctx = find_widget(snap, "MAIN_WIN/CTX")
        t |> equal(ctx?["kind"] ?? "", "popup_context_window",
                   "CTX.kind == 'popup_context_window'")
        t |> equal(widget_payload_field(snap, "MAIN_WIN/STATUS", "value") ?? "",
                   "last pick: (none yet)",
                   "STATUS shows '(none yet)' initially")
        t |> success(!widget_exists(snap, "MAIN_WIN/CTX/ITEM_NEW"),
                     "ITEM_NEW absent while popup closed")

        // Right-click LEAD via raw synth to open the popup.
        let (lead_x, lead_y) = bbox_center(snap, "MAIN_WIN/LEAD")
        rmb_release_at(d, lead_x, lead_y)
        var snap_open = wait_for_widget(d, "MAIN_WIN/CTX/ITEM_NEW", 5.0f)
        t |> success(snap_open != null, "ITEM_NEW registers after RMB on LEAD")
        if (snap_open == null) return

        // Pick "New" via raw LMB. menu_item's L2 dispatcher would flip
        // ToggleState.value but the demo's `if (menu_item(...))` branch only
        // fires for a real mouse click.
        let (new_x, new_y) = bbox_center(snap_open, "MAIN_WIN/CTX/ITEM_NEW")
        lmb_release_at(d, new_x, new_y)
        t |> success(wait_for_string_value(d, "MAIN_WIN/STATUS", "value",
                                           "last pick: New", 300),
                     "STATUS reflects 'New' after menu pick")

        // Re-open + pick "Quit" — verifies the popup can be re-opened. Same
        // raw-synth pathway as above; no coroutine race with the persistent
        // synth state.
        rmb_release_at(d, lead_x, lead_y)
        var snap_open2 = wait_for_widget(d, "MAIN_WIN/CTX/ITEM_QUIT", 5.0f)
        t |> success(snap_open2 != null, "ITEM_QUIT registers on re-open")
        if (snap_open2 == null) return
        let (quit_x, quit_y) = bbox_center(snap_open2, "MAIN_WIN/CTX/ITEM_QUIT")
        lmb_release_at(d, quit_x, quit_y)
        t |> success(wait_for_string_value(d, "MAIN_WIN/STATUS", "value",
                                           "last pick: Quit", 300),
                     "STATUS reflects 'Quit' after second menu pick")
    }
}
