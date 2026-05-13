options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
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

def click_at(var events : array<JsonValue?>; t_ms : int; pos : tuple<float; float>) {
    //! Append move + press + release + dwell. See record_visual_aids.das for
    //! the trailing dwell rationale.
    events |> push(JV((t_ms = t_ms,       kind = "move",   x = pos._0, y = pos._1)))
    events |> push(JV((t_ms = t_ms + 200, kind = "button", button = 0, action = "press")))
    events |> push(JV((t_ms = t_ms + 300, kind = "button", button = 0, action = "release")))
    events |> push(JV((t_ms = t_ms + 500, kind = "move",   x = pos._0, y = pos._1)))
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

    var snap = wait_for_render(app, "EXPLORE_BTN", 10.0f)
    if (snap == null) {
        panic("EXPLORE_BTN never rendered — wrong app running on {BASE_URL}?")
    }
    let p_explore = widget_center(snap, "EXPLORE_BTN")
    let p_file_a  = widget_center(snap, "FILE_A_BTN")

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 60)))

    // ---- Stage 1: sidebar (dock_left) ----
    post_command(app, "imgui_narrate", JV((
        text = "dock_left fixes a sidebar to the left edge.",
        target = "SIDEBAR",
        frames = 180
    )))
    sleep(900u)
    post_command(app, "imgui_set", JV((target = "SIDEBAR", value = 260.0f)))
    sleep(1400u)

    // ---- Stage 2: horizontal splitter (split_h on top half) ----
    post_command(app, "imgui_narrate", JV((
        text = "split_h slices the top into left + right.",
        target = "SPLIT_MAIN",
        frames = 180
    )))
    sleep(900u)
    post_command(app, "imgui_set", JV((target = "SPLIT_MAIN", value = 0.6f)))
    sleep(1400u)

    // ---- Stage 3: vertical splitter ----
    post_command(app, "imgui_narrate", JV((
        text = "split_v splits top from bottom.",
        target = "SPLIT_VERT",
        frames = 180
    )))
    sleep(900u)
    post_command(app, "imgui_set", JV((target = "SPLIT_VERT", value = 0.45f)))
    sleep(1400u)

    // ---- Stage 4: click inside sidebar ----
    post_command(app, "imgui_narrate", JV((
        text = "Each pane clips its widgets cleanly.",
        target = "EXPLORE_BTN",
        frames = 180
    )))
    sleep(700u)
    var explore_events : array<JsonValue?>
    explore_events |> click_at(0, p_explore)
    post_command(app, "imgui_mouse_play", JV((events = explore_events)))
    sleep(1400u)

    // ---- Stage 5: click inside left-split pane (re-resolve bbox; layout shifted) ----
    snap = wait_for_render(app, "FILE_A_BTN", 5.0f)
    let p_file_a_now = snap != null ? widget_center(snap, "FILE_A_BTN") : p_file_a
    post_command(app, "imgui_narrate", JV((
        text = "Splitters re-flow the panes on every drag.",
        target = "FILE_A_BTN",
        frames = 180
    )))
    sleep(700u)
    var file_events : array<JsonValue?>
    file_events |> click_at(0, p_file_a_now)
    post_command(app, "imgui_mouse_play", JV((events = file_events)))
    sleep(1600u)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
