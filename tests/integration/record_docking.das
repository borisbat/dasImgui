options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``docking.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_docking.das
//!
//! Mirrors record_layout.das.

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
    with_recording_app("examples/tutorial/docking.das",
                       "docking.apng", 60) $(app) {
        //! Targets are path-qualified — dockspace pushes onto the registry path.
        let T_EXPLORER    = "DOCK_ROOT/EXPLORER"
        let T_SOURCE      = "DOCK_ROOT/SOURCE"
        let T_OUTPUT      = "DOCK_ROOT/OUTPUT"
        let T_REFRESH_BTN = "DOCK_ROOT/EXPLORER/REFRESH_BTN"
        let T_SAVE_BTN    = "DOCK_ROOT/SOURCE/SAVE_BTN"
        let T_CLEAR_BTN   = "DOCK_ROOT/OUTPUT/CLEAR_BTN"

        var snap = wait_for_render(app, T_REFRESH_BTN, 10.0f)
        if (snap == null) {
            panic("{T_REFRESH_BTN} never rendered — wrong app running?")
        }
        let p_refresh = widget_center(snap, T_REFRESH_BTN)
        let p_save    = widget_center(snap, T_SAVE_BTN)
        let p_clear   = widget_center(snap, T_CLEAR_BTN)

        //! Pacing rule (LOCKED): `frames` is the app's frame counter (60 fps
        //! under vsync), NOT the recorder's fps. For ~3s readable narrate:
        //!     frames = 180   →  3.0s visible
        //!     sleep  = 3500u →  narrate disappears with ~500ms gap before next
        //! Then ~1500ms for the actual interaction (click / drag / dwell).

        // ---- Stage 1: tour the docked panels ----
        post_command(app, "imgui_narrate", JV((
            text = "ImGui native docking — three dockable panels.",
            target = T_EXPLORER,
            frames = 180
        )))
        move_to(app, p_refresh)
        sleep(3500u)

        post_command(app, "imgui_narrate", JV((
            text = "Each panel is a Begin/End window inside the dockspace.",
            target = T_SOURCE,
            frames = 180
        )))
        move_to(app, p_save)
        sleep(3500u)

        post_command(app, "imgui_narrate", JV((
            text = "Tabs are draggable — layout persists via imgui.ini.",
            target = T_OUTPUT,
            frames = 180
        )))
        move_to(app, p_clear)
        sleep(3500u)

        // ---- Stage 2: drive from outside — imgui_undock pops OUTPUT out ----
        // After undocking, ImGui places the floating window wherever imgui.ini
        // remembered (or (0,0) on first run). Pin it to a visible location with
        // imgui_set_window_pos so the demo clearly shows the panel detached.
        post_command(app, "imgui_narrate", JV((
            text = "imgui_undock + imgui_set_window_pos — panel floats free.",
            target = T_OUTPUT,
            frames = 200
        )))
        sleep(800u)
        post_command(app, "imgui_undock", JV((target = T_OUTPUT)))
        post_command(app, "imgui_set_window_pos", JV((
            target = T_OUTPUT,
            value = (x = 580.0f, y = 220.0f, w = 360.0f, h = 220.0f)
        )))
        sleep(3700u)

        // ---- Stage 3: reset the dockspace ----
        post_command(app, "imgui_narrate", JV((
            text = "imgui_dock_reset rebuilds the default layout.",
            target = T_EXPLORER,
            frames = 180
        )))
        sleep(800u)
        post_command(app, "imgui_dock_reset", JV((target = "DOCK_ROOT")))
        sleep(3000u)
    }
}
