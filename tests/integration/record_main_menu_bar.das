options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``main_menu_bar.apng`` against
//! ``examples/tutorial/main_menu_bar.das``. Tours the screen-top
//! ``main_menu_bar`` container + the ``menu_item`` (toggleable) vs
//! ``menu_label`` (static, click-counting) split.
//!
//! Menu interactions are bundled into one ``imgui_mouse_play`` per
//! menu (header click + child click in the same event sequence). A
//! split-stream approach (two separate mouse_play calls) lets ImGui
//! auto-close the menu between events, because the cursor goes idle
//! between the two streams and the menu's auto-close timer fires.

let MENU_DWELL_MS = 3500u       //! settle for combined menu open + child click
let RESULT_MS  = 2000u          //! 2s post-click dwell

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
    with_recording_app("examples/tutorial/main_menu_bar.das",
                       "main_menu_bar.apng", 60) $(app) {
        let T_FILE = "MAIN_BAR/FILE_MENU"
        let T_EDIT = "MAIN_BAR/EDIT_MENU"
        let T_BODY = "BODY"

        var snap = wait_for_render(app, T_FILE, 10.0f)
        if (snap == null) {
            panic("{T_FILE} never rendered — wrong app running?")
        }
        let p_file = widget_center(snap, T_FILE)
        let p_edit = widget_center(snap, T_EDIT)
        let p_body = widget_center(snap, T_BODY)

        //! Initial cursor placement — flips synth_cursor_owned.
        move_to(app, p_body, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: hover the File menu header (narrate only) ----
        move_to(app, p_file, 900)
        sleep(SETTLE_MS)
        say(app, "main_menu_bar(IDENT) wraps BeginMainMenuBar/EndMainMenuBar — the screen-top strip. menu() children register routable headers under MAIN_BAR/.", T_FILE)

        // ---- Stage 2: click File, lerp into menu, click Dark mode ----
        //! MI_DARKMODE.bbox isn't known until the menu opens, but we know
        //! the menu opens DOWN from the header — estimate the position by
        //! adding a known offset from p_file (header height + item index).
        //! Once open, items are ~22px tall in the default font; MI_DARKMODE
        //! is the first one (y = header_bottom + 14).
        let p_darkmode = (p_file._0, p_file._1 + 32.0f)
        var open_file_events : array<JsonValue?>
        open_file_events |> click_at(0, p_file, 200)
        open_file_events |> click_at(1200, p_darkmode, 600)
        post_command(app, "imgui_mouse_play", JV((events = open_file_events)))
        sleep(MENU_DWELL_MS)

        say(app, "Click File, then Dark mode — MI_DARKMODE.value flips. menu_item is the toggleable variant; menu_label (used below for recent files / Star this project) is static.", T_BODY)

        // ---- Stage 3: click Edit, lerp to Undo, click Undo ----
        let p_undo = (p_edit._0, p_edit._1 + 32.0f)
        var open_edit_events : array<JsonValue?>
        open_edit_events |> click_at(0, p_edit, 600)
        open_edit_events |> click_at(1500, p_undo, 500)
        post_command(app, "imgui_mouse_play", JV((events = open_edit_events)))
        sleep(MENU_DWELL_MS)

        say(app, "Edit > Undo uses menu_label — clicks increment EDIT_UNDO.click_count without toggling. The body window mirrors both counters in real time.", T_BODY)

        // ---- Stage 4: settle on the state readout ----
        move_to(app, p_body, 900)
        sleep(RESULT_MS)
    }
}
