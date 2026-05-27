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
//!
//! Drives the General tab's WIRE checkbox, opens the popup, toggles
//! OPT_VSYNC inside it, hovers HOVER_BTN for item_tooltip. Tab
//! switching across tab_bar headers needs ImGuiTabItemFlags.SetSelected
//! plumbing the boost wrapper doesn't expose — narrated as "try live"
//! rather than driven, until that rail lands.

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
                       "containers.apng", 75) $(app) {
        //! Targets are path-qualified — `window`, `menu_bar`, `tab_bar`, etc.
        //! all push their identifier onto the registry path. Note that menu
        //! and tab-item HEADER bboxes aren't registered (ImGui draws them as
        //! chrome before the body block runs); we point narrates at child
        //! widgets inside the active tab instead.
        let T_WIRE        = "CONT_WIN/MAIN_TABS/GENERAL_TAB/WIRE"
        let T_OPEN_POPUP  = "CONT_WIN/OPEN_POPUP_BTN"
        let T_POPUP       = "CONT_WIN/OPTIONS_POPUP"
        let T_OPT_VSYNC   = "CONT_WIN/OPTIONS_POPUP/OPT_VSYNC"
        let T_HOVER       = "CONT_WIN/HOVER_BTN"

        var snap = wait_for_render(app, T_OPEN_POPUP, 10.0f)
        if (snap == null) {
            panic("{T_OPEN_POPUP} never rendered — wrong app running?")
        }
        let p_open_popup = widget_center(snap, T_OPEN_POPUP)
        let p_hover      = widget_center(snap, T_HOVER)
        let p_wire       = widget_center(snap, T_WIRE)

        // ---- Stage 1: General tab + menu_bar + WIRE checkbox ----
        move_to(app, p_wire)
        sleep(SETTLE_MS)
        say(app, "menu_bar and tab_bar share the window chrome. General tab is active by default; WIRE checkbox lives in its body. Try Audio / Info tabs live — tab switching needs ImGuiTabItemFlags.SetSelected which the synth doesn't expose yet.", T_WIRE)
        click(app, T_WIRE)
        sleep(CLICK_DWELL_MS)
        say(app, "WIRE flipped — General tab's body runs every frame; inactive tabs (Audio, Info) don't enter their body block.", T_WIRE)

        // ---- Stage 2: popup open via button click, then drive a checkbox inside ----
        move_to(app, p_open_popup)
        sleep(SETTLE_MS)
        var open_events : array<JsonValue?>
        open_events |> click_at(0, p_open_popup)
        post_command(app, "imgui_mouse_play", JV((events = open_events)))
        sleep(CLICK_DWELL_MS)
        var snap_popup = wait_for_widget(app, T_OPT_VSYNC, 5.0f)
        if (snap_popup == null) {
            panic("{T_OPT_VSYNC} never registered after opening popup")
        }
        let p_opt_vsync = widget_center(snap_popup, T_OPT_VSYNC)

        move_to(app, p_opt_vsync)
        sleep(SETTLE_MS)
        click(app, T_OPT_VSYNC)
        sleep(CLICK_DWELL_MS)
        say(app, "popup — opened via pending_open (the button flipped the flag). OPT_VSYNC checkbox lives inside the popup body; the path push works across the popup boundary.", T_OPT_VSYNC)

        // Close it via the same channel imgui_close uses.
        post_command(app, "imgui_close", JV((target = T_POPUP)))
        sleep(CLICK_DWELL_MS)

        // ---- Stage 3: item_tooltip on hover ----
        move_to(app, p_hover)
        sleep(SETTLE_MS)
        say(app, "item_tooltip — auto-gated by IsItemHovered. Dwell on the button below; the BeginItemTooltip block runs while hovered.", T_HOVER)
        sleep(2500u)
    }
}
