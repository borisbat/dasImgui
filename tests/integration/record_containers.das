options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``containers.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_containers.das

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
    with_recording_app("examples/tutorial/containers.das",
                       "containers.apng", 60) $(app) {
        //! Targets are path-qualified — `window`, `menu_bar`, `tab_bar`, etc.
        //! all push their identifier onto the registry path. Note that menu
        //! and tab-item HEADER bboxes aren't registered (ImGui draws them as
        //! chrome before the body block runs); we point narrates at child
        //! widgets inside the active tab instead.
        let T_WIRE        = "CONT_WIN/MAIN_TABS/GENERAL_TAB/WIRE"
        let T_OPEN_POPUP  = "CONT_WIN/OPEN_POPUP_BTN"
        let T_POPUP       = "CONT_WIN/OPTIONS_POPUP"
        let T_HOVER       = "CONT_WIN/HOVER_BTN"

        var snap = wait_for_render(app, T_OPEN_POPUP, 10.0f)
        if (snap == null) {
            panic("{T_OPEN_POPUP} never rendered — wrong app running?")
        }
        let p_open_popup = widget_center(snap, T_OPEN_POPUP)
        let p_hover      = widget_center(snap, T_HOVER)
        let p_wire       = widget_center(snap, T_WIRE)

        //! Pacing rule (LOCKED): `frames` is the app's frame counter (60 fps
        //! under vsync), NOT the recorder's fps. For ~3s readable narrate:
        //!     frames = 180   →  3.0s visible
        //!     sleep  = 3500u →  narrate disappears with ~500ms gap before next
        //! Then ~1500ms result dwell after the action.

        // ---- Stage 1: menu bar + tab bar — narrate the chrome ----
        // The menu bar and tab headers are ImGui-drawn chrome above any
        // registered widget. The cursor sits at the top of the General tab
        // (WIRE) so the menu bar and tab strip are both in view.
        post_command(app, "imgui_narrate", JV((
            text = "menu_bar and tab_bar share the window chrome.",
            target = T_WIRE,
            frames = 200
        )))
        move_to(app, p_wire)
        sleep(3500u)
        post_command(app, "imgui_narrate", JV((
            text = "Only the active tab's block runs each frame.",
            target = T_WIRE,
            frames = 200
        )))
        sleep(3500u)

        // ---- Stage 2: popup via pending_open ----
        post_command(app, "imgui_narrate", JV((
            text = "popup — open via the button (pending_open).",
            target = T_OPEN_POPUP,
            frames = 200
        )))
        move_to(app, p_open_popup)
        sleep(3500u)
        var open_events : array<JsonValue?>
        open_events |> click_at(0, p_open_popup)
        post_command(app, "imgui_mouse_play", JV((events = open_events)))
        sleep(2000u)
        // Close it via the same channel imgui_close uses.
        post_command(app, "imgui_close", JV((target = T_POPUP)))
        sleep(1500u)

        // ---- Stage 3: item_tooltip on hover ----
        post_command(app, "imgui_narrate", JV((
            text = "item_tooltip — auto-gated by IsItemHovered.",
            target = T_HOVER,
            frames = 200
        )))
        move_to(app, p_hover)
        sleep(3500u)
        // Dwell on the button so ImGui's hover delay fires the tooltip.
        sleep(2500u)
    }
}
