options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``layout.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_layout.das
//!
//! Mirrors record_widgets_tour.das.

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
    with_recording_app("examples/tutorial/layout.das",
                       "layout.apng", 90) $(app) {
        //! All boost widgets are nested under ``window(LAYOUT_WIN, ...)`` in
        //! layout.das, so every registered key is path-prefixed. dock_left and
        //! split_* helpers also appear in the registry but with bbox=(0,0,0,0)
        //! (the splitter handle is an InvisibleButton not separately registered —
        //! see test_layout_helpers.das:115-122 TODO). We narrate against and move
        //! the cursor to a child button in each helper's pane instead.
        let T_SIDEBAR     = "LAYOUT_WIN/SIDEBAR"
        let T_SPLIT_MAIN  = "LAYOUT_WIN/SPLIT_VERT/SPLIT_MAIN"
        let T_SPLIT_VERT  = "LAYOUT_WIN/SPLIT_VERT"
        let T_EXPLORE_BTN = "LAYOUT_WIN/SIDEBAR/EXPLORE_BTN"
        let T_FILE_A_BTN  = "LAYOUT_WIN/SPLIT_VERT/SPLIT_MAIN/FILE_A_BTN"
        let T_CLEAR_BTN   = "LAYOUT_WIN/SPLIT_VERT/CLEAR_BTN"

        var snap = wait_for_render(app, T_EXPLORE_BTN, 10.0f)
        if (snap == null) {
            panic("{T_EXPLORE_BTN} never rendered — wrong app running?")
        }
        let p_explore = widget_center(snap, T_EXPLORE_BTN)
        let p_file_a  = widget_center(snap, T_FILE_A_BTN)
        let p_clear   = widget_center(snap, T_CLEAR_BTN)

        // ---- Stage 1: sidebar (dock_left) ----
        // Narrate against EXPLORE_BTN (a real bbox inside the sidebar) since
        // dock_left itself has bbox=(0,0,0,0). Cursor moves into the sidebar.
        move_to(app, p_explore)
        say(app, "dock_left fixes a sidebar to the left edge.", T_EXPLORE_BTN)
        post_command(app, "imgui_set", JV((target = T_SIDEBAR, value = 260.0f)))
        sleep(CLICK_DWELL_MS)

        // ---- Stage 2: horizontal splitter (split_h on top half) ----
        // Re-resolve FILE_A_BTN bbox; SIDEBAR's resize reflowed the panes.
        // Narrate against FILE_A_BTN (left split pane) — split_h has no bbox.
        snap = wait_for_render(app, T_FILE_A_BTN, 3.0f)
        let p_file_a_now = snap != null ? widget_center(snap, T_FILE_A_BTN) : p_file_a
        move_to(app, p_file_a_now)
        say(app, "split_h slices the top into left + right.", T_FILE_A_BTN)
        post_command(app, "imgui_set", JV((target = T_SPLIT_MAIN, value = 0.6f)))
        sleep(CLICK_DWELL_MS)

        // ---- Stage 3: vertical splitter ----
        // Narrate against CLEAR_BTN (bottom pane) — split_v has no bbox.
        snap = wait_for_render(app, T_CLEAR_BTN, 3.0f)
        let p_clear_now = snap != null ? widget_center(snap, T_CLEAR_BTN) : p_clear
        move_to(app, p_clear_now)
        say(app, "split_v splits top from bottom.", T_CLEAR_BTN)
        post_command(app, "imgui_set", JV((target = T_SPLIT_VERT, value = 0.45f)))
        sleep(CLICK_DWELL_MS)

        // ---- Stage 4: click inside sidebar ----
        snap = wait_for_render(app, T_EXPLORE_BTN, 3.0f)
        let p_explore_now = snap != null ? widget_center(snap, T_EXPLORE_BTN) : p_explore
        say(app, "Each pane clips its widgets cleanly.", T_EXPLORE_BTN)
        var explore_events : array<JsonValue?>
        explore_events |> click_at(0, p_explore_now)
        post_command(app, "imgui_mouse_play", JV((events = explore_events)))
        sleep(CLICK_DWELL_MS)

        // ---- Stage 5: click inside left-split pane (re-resolve bbox; layout shifted) ----
        snap = wait_for_render(app, T_FILE_A_BTN, 5.0f)
        let p_file_a_now2 = snap != null ? widget_center(snap, T_FILE_A_BTN) : p_file_a_now
        say(app, "Splitters re-flow the panes on every drag.", T_FILE_A_BTN)
        var file_events : array<JsonValue?>
        file_events |> click_at(0, p_file_a_now2)
        post_command(app, "imgui_mouse_play", JV((events = file_events)))
        sleep(1700u)
    }
}
