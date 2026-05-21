options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``popup_window.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_popup_window.das

let NARRATE_FRAMES = 200
let READ_MS    = 3500u
let SETTLE_MS  = 1500u
let RESULT_MS  = 1500u
let TAIL_MS    = 1500u

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
    with_recording_app("examples/features/popup_window.das",
                       "popup_window.apng", 35) $(app) {
        let T_OPEN_BTN = "MAIN_WIN/via_button/OPEN_BTN"
        let T_HINT     = "MAIN_WIN/via_region/HOVER_HINT"

        var snap = wait_for_render(app, T_OPEN_BTN, 10.0f)
        if (snap == null) {
            panic("{T_OPEN_BTN} never rendered — wrong app running?")
        }
        let p_open  = widget_center(snap, T_OPEN_BTN)
        let p_hint  = widget_center(snap, T_HINT)

        // ---- Stage 1: introduce the manual-trigger pattern ----
        post_command(app, "imgui_narrate", JV((
            text = "popup_window has no auto-trigger — caller drives open_popup.",
            target = T_OPEN_BTN,
            frames = NARRATE_FRAMES
        )))
        move_to(app, p_open)
        sleep(READ_MS)

        // ---- Stage 2: left-click → BTN_POPUP opens ----
        post_command(app, "imgui_narrate", JV((
            text = "Click fires open_popup(\"fruit_picker\"); popup_window brackets the body.",
            target = T_OPEN_BTN,
            frames = NARRATE_FRAMES
        )))
        var click_events : array<JsonValue?>
        click_events |> click_at(0, p_open)
        post_command(app, "imgui_mouse_play", JV((events = click_events)))
        sleep(RESULT_MS)

        // Re-snapshot to find the freshly-opened popup body widget bboxes.
        // wait_for_widget gates on path EXISTENCE (vs wait_for_render's
        // `?? true` which silently passes when the indexed-path is absent).
        var snap2 = wait_for_widget(app,
            "MAIN_WIN/via_button/BTN_POPUP/PICK_APPLE", 5.0f)
        if (snap2 == null) {
            panic("BTN_POPUP body never rendered — click didn't open the popup?")
        }
        let p_apple = widget_center(snap2, "MAIN_WIN/via_button/BTN_POPUP/PICK_APPLE")

        // ---- Stage 3: pick a fruit → close_current_popup closes the popup ----
        post_command(app, "imgui_narrate", JV((
            text = "menu_label fires close_current_popup; popup closes, status updates.",
            target = "MAIN_WIN/via_button/BTN_POPUP/PICK_APPLE",
            frames = NARRATE_FRAMES
        )))
        var apple_events : array<JsonValue?>
        apple_events |> click_at(0, p_apple)
        post_command(app, "imgui_mouse_play", JV((events = apple_events)))
        sleep(RESULT_MS)

        // ---- Stage 4: highlight the hover-region scope ----
        post_command(app, "imgui_narrate", JV((
            text = "Second scope shares the same str_id; with_id keeps each scope's open state distinct.",
            target = T_HINT,
            frames = NARRATE_FRAMES
        )))
        move_to(app, p_hint)
        sleep(READ_MS)

        // ---- Stage 5: right-click in the hover region → REG_POPUP opens ----
        post_command(app, "imgui_narrate", JV((
            text = "Right-click on the hover region — no preceding 'item' needed.",
            target = T_HINT,
            frames = NARRATE_FRAMES
        )))
        var rclick_events : array<JsonValue?>
        rclick_events |> click_at(0, p_hint, 500, 1) //! button=1 → right
        post_command(app, "imgui_mouse_play", JV((events = rclick_events)))
        sleep(RESULT_MS)

        var snap3 = wait_for_widget(app,
            "MAIN_WIN/via_region/REG_POPUP/PICK_BANANA", 5.0f)
        if (snap3 == null) {
            panic("REG_POPUP body never rendered — right-click didn't open the popup?")
        }
        let p_banana = widget_center(snap3,
            "MAIN_WIN/via_region/REG_POPUP/PICK_BANANA")

        var banana_events : array<JsonValue?>
        banana_events |> click_at(0, p_banana)
        post_command(app, "imgui_mouse_play", JV((events = banana_events)))
        sleep(RESULT_MS)
        sleep(TAIL_MS)
    }
}
