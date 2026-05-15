options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options _no_imgui_legacy = true

require imgui public
require imgui/imgui_lint
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``layout.apng`` against an **already-running**
//! daslang-live. Mirrors record_widgets_tour.das.
//!
//! Workflow (two shells):
//!
//!     # window 1 — host with cwd = the asset dir so the APNG lands there:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/tutorial/layout.das
//!
//!     # window 2 — fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_layout.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "layout.apng"

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
    let app = ImguiApp(
        base_url = BASE_URL,
        feature_path = "",
        transport <- live_api_transport(BASE_URL)
    )
    print("[record] connecting to {BASE_URL}\n")
    if (!wait_until_ready(app, 5.0f)) {
        panic("daslang-live not responding on {BASE_URL} — is it running with layout.das?")
    }

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
        panic("{T_EXPLORE_BTN} never rendered — wrong app running on {BASE_URL}?")
    }
    let p_explore = widget_center(snap, T_EXPLORE_BTN)
    let p_file_a  = widget_center(snap, T_FILE_A_BTN)
    let p_clear   = widget_center(snap, T_CLEAR_BTN)

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 90)))

    //! Pacing rule (LOCKED): `frames` is the app's frame counter (60 fps
    //! under vsync), NOT the recorder's fps. For ~3s readable narrate:
    //!     frames = 180   →  3.0s visible
    //!     sleep  = 3500u →  narrate disappears with ~500ms gap before next
    //! Then ~1500ms result dwell after the action.

    // ---- Stage 1: sidebar (dock_left) ----
    // Narrate against EXPLORE_BTN (a real bbox inside the sidebar) since
    // dock_left itself has bbox=(0,0,0,0). Cursor moves into the sidebar.
    post_command(app, "imgui_narrate", JV((
        text = "dock_left fixes a sidebar to the left edge.",
        target = T_EXPLORE_BTN,
        frames = 200
    )))
    move_to(app, p_explore)
    sleep(3500u)
    post_command(app, "imgui_set", JV((target = T_SIDEBAR, value = 260.0f)))
    sleep(1500u)

    // ---- Stage 2: horizontal splitter (split_h on top half) ----
    // Re-resolve FILE_A_BTN bbox; SIDEBAR's resize reflowed the panes.
    // Narrate against FILE_A_BTN (left split pane) — split_h has no bbox.
    snap = wait_for_render(app, T_FILE_A_BTN, 3.0f)
    let p_file_a_now = snap != null ? widget_center(snap, T_FILE_A_BTN) : p_file_a
    post_command(app, "imgui_narrate", JV((
        text = "split_h slices the top into left + right.",
        target = T_FILE_A_BTN,
        frames = 200
    )))
    move_to(app, p_file_a_now)
    sleep(3500u)
    post_command(app, "imgui_set", JV((target = T_SPLIT_MAIN, value = 0.6f)))
    sleep(1500u)

    // ---- Stage 3: vertical splitter ----
    // Narrate against CLEAR_BTN (bottom pane) — split_v has no bbox.
    snap = wait_for_render(app, T_CLEAR_BTN, 3.0f)
    let p_clear_now = snap != null ? widget_center(snap, T_CLEAR_BTN) : p_clear
    post_command(app, "imgui_narrate", JV((
        text = "split_v splits top from bottom.",
        target = T_CLEAR_BTN,
        frames = 200
    )))
    move_to(app, p_clear_now)
    sleep(3500u)
    post_command(app, "imgui_set", JV((target = T_SPLIT_VERT, value = 0.45f)))
    sleep(1500u)

    // ---- Stage 4: click inside sidebar ----
    snap = wait_for_render(app, T_EXPLORE_BTN, 3.0f)
    let p_explore_now = snap != null ? widget_center(snap, T_EXPLORE_BTN) : p_explore
    post_command(app, "imgui_narrate", JV((
        text = "Each pane clips its widgets cleanly.",
        target = T_EXPLORE_BTN,
        frames = 180
    )))
    sleep(3500u)
    var explore_events : array<JsonValue?>
    explore_events |> click_at(0, p_explore_now)
    post_command(app, "imgui_mouse_play", JV((events = explore_events)))
    sleep(1500u)

    // ---- Stage 5: click inside left-split pane (re-resolve bbox; layout shifted) ----
    snap = wait_for_render(app, T_FILE_A_BTN, 5.0f)
    let p_file_a_now2 = snap != null ? widget_center(snap, T_FILE_A_BTN) : p_file_a_now
    post_command(app, "imgui_narrate", JV((
        text = "Splitters re-flow the panes on every drag.",
        target = T_FILE_A_BTN,
        frames = 180
    )))
    sleep(3500u)
    var file_events : array<JsonValue?>
    file_events |> click_at(0, p_file_a_now2)
    post_command(app, "imgui_mouse_play", JV((events = file_events)))
    sleep(1700u)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
