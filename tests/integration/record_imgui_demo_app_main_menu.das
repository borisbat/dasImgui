options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``imgui_demo_app_main_menu.apng`` against an
//! **already-running** daslang-live hosting harness_app_main_menu.das.
//!
//! Workflow (two shells):
//!
//!     # window 1 -- host with cwd = the asset dir so the APNG lands there:
//!     cd modules/dasImgui/doc/source/_static/tutorials
//!     ../../../../../../bin/Release/daslang-live.exe \
//!         ../../../../examples/imgui_demo/harness_app_main_menu.das
//!
//!     # window 2 -- fire the driver, exits when done:
//!     bin/Release/daslang.exe modules/dasImgui/tests/integration/record_imgui_demo_app_main_menu.das

let BASE_URL = "http://127.0.0.1:9090"
let OUTPUT   = "imgui_demo_app_main_menu.apng"

//! Menu-header pixel coords are EMPIRICAL: `main_menu_bar` and its `menu()`
//! children register stateless_finalize() bboxes as (0,0,0,0) because ImGui's
//! GetItemRectMin/Max returns degenerate values for menu-bar chrome at
//! finalize time. Until that's fixed (followup), hardcode the visual coords.
let P_FILE_HEADER    = (24.0f,  10.0f)   //! "File"  label, centered y=10
let P_EDIT_HEADER    = (56.0f,  10.0f)   //! "Edit"  label, after "File "
let P_FILE_COLORS    = (50.0f, 173.0f)   //! Colors row inside File menu

//! Reader pacing: narrate frames=240 -> 4.0s visible at 60 fps app. Then
//! sleep ~5s lets reader finish + 1s gap before the next action.
let NARRATE_FRAMES   = 240
let READ_MS          = 5000u
let SETTLE_MS        = 1500u
let RESULT_MS        = 2000u

[export]
def main {
    let app = ImguiApp(
        base_url = BASE_URL,
        feature_path = "",
        transport <- live_api_transport(BASE_URL)
    )
    print("[record] connecting to {BASE_URL}\n")
    if (!wait_until_ready(app, 5.0f)) {
        panic("daslang-live not responding on {BASE_URL} -- is it running with harness_app_main_menu.das?")
    }

    var snap = wait_for_render(app, "MAIN_BAR_DEMO", 10.0f)
    if (snap == null) {
        panic("MAIN_BAR_DEMO never rendered -- wrong app running on {BASE_URL}?")
    }

    post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
    post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
    post_command(app, "record_start", JV((file = OUTPUT, fps = 30, max_seconds = 45)))

    //! Initial cursor placement (synth IO flips `cursor_owned` on first move).
    move_to(app, (360.0f, 240.0f), 600)
    sleep(SETTLE_MS)

    // ---- Stage 1: narrate the menu bar ----
    move_to(app, (360.0f, 30.0f), 900)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "Main menu bar -- daslang port of ShowExampleAppMainMenuBar.",
        target = "MAIN_BAR_DEMO",
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 2: click File menu -- cascade opens ----
    move_to(app, P_FILE_HEADER, 900)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "Click 'File' to open the cascading menu.",
        target = "MAIN_BAR_DEMO/APP_MENU_FILE",
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)
    var file_events : array<JsonValue?>
    file_events |> click_at(0, P_FILE_HEADER, 250)
    post_command(app, "imgui_mouse_play", JV((events = file_events)))
    sleep(RESULT_MS)
    post_command(app, "imgui_narrate", JV((
        text = "File menu: Options, Colors, Open Recent, More.., Disabled, Checked.",
        target = "MAIN_BAR_DEMO/APP_MENU_FILE",
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 3: hover Colors row -- submenu cascades with per-color swatches ----
    move_to(app, P_FILE_COLORS, 900)
    sleep(SETTLE_MS)
    post_command(app, "imgui_narrate", JV((
        text = "Colors submenu: per-color swatches paint via GetWindowDrawList + AddRectFilled.",
        target = "MAIN_BAR_DEMO/APP_MENU_FILE",
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    // ---- Stage 4: close menu (click File again), then open Edit ----
    var close_events : array<JsonValue?>
    close_events |> click_at(0, P_FILE_HEADER, 700)
    post_command(app, "imgui_mouse_play", JV((events = close_events)))
    sleep(RESULT_MS)

    move_to(app, P_EDIT_HEADER, 600)
    sleep(SETTLE_MS)
    var edit_events : array<JsonValue?>
    edit_events |> click_at(0, P_EDIT_HEADER, 250)
    post_command(app, "imgui_mouse_play", JV((events = edit_events)))
    sleep(RESULT_MS)
    post_command(app, "imgui_narrate", JV((
        text = "Edit menu: Undo / Redo / Cut / Copy / Paste -- menu_label gates non-toggling items.",
        target = "MAIN_BAR_DEMO/APP_MENU_EDIT",
        frames = NARRATE_FRAMES
    )))
    sleep(READ_MS)

    let stopped = post_command(app, "record_stop", null)
    let stop_dump = stopped != null ? write_json(stopped) : "<null>"
    print("[record] record_stop -> {stop_dump}\n")
    print("[record] APNG saved to {OUTPUT} (next to daslang-live's CWD)\n")

    post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
    post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
}
