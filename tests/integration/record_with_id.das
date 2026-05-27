options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``with_id.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_with_id.das

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
    with_recording_app("examples/tutorial/with_id.das",
                       "with_id.apng", 60) $(app) {
        //! Targets are path-qualified — the `window(ID_WIN, ...)` boost
        //! container pushes its name, and `with_id("…")` adds further segments.
        let T_SAVE_A      = "ID_WIN/section_a/SAVE_BTN"
        let T_SAVE_B      = "ID_WIN/section_b/SAVE_BTN"
        let T_NESTED      = "ID_WIN/outer/inner/NESTED_BTN"
        let T_HASHED      = "ID_WIN/HASHED_BTN"
        let T_RPS_PATH    = "ID_WIN/rps_stable"

        var snap = wait_for_render(app, T_SAVE_A, 10.0f)
        if (snap == null) {
            panic("{T_SAVE_A} never rendered — wrong app running?")
        }
        let p_save_a  = widget_center(snap, T_SAVE_A)
        let p_save_b  = widget_center(snap, T_SAVE_B)
        let p_nested  = widget_center(snap, T_NESTED)
        let p_hashed  = widget_center(snap, T_HASHED)
        let p_rps     = widget_center(snap, T_RPS_PATH)

        //! Slider drag (path= demo): drag from 15% to 75% along the slider bbox.
        let rps_bb = widget_bbox(snap, T_RPS_PATH)
        let rps_y  = (rps_bb.y + rps_bb.w) * 0.5f
        let rps_x0 = rps_bb.x + (rps_bb.z - rps_bb.x) * 0.15f
        let rps_x1 = rps_bb.x + (rps_bb.z - rps_bb.x) * 0.75f

        // ---- Stage 1: two scopes, same widget identifier ----
        move_to(app, p_save_a)
        say(app, "with_id scopes a render — same SAVE_BTN, two paths.", T_SAVE_A)
        var save_a_events : array<JsonValue?>
        save_a_events |> click_at(0, p_save_a)
        post_command(app, "imgui_mouse_play", JV((events = save_a_events)))
        sleep(1500u)

        move_to(app, p_save_b)
        say(app, "section_b path → distinct ImGui hash + own click count slot.", T_SAVE_B)
        var save_b_events : array<JsonValue?>
        save_b_events |> click_at(0, p_save_b)
        post_command(app, "imgui_mouse_play", JV((events = save_b_events)))
        sleep(1500u)

        // ---- Stage 2: nested with_id chain ----
        move_to(app, p_nested)
        say(app, "Nested with_id — segments join with /.", T_NESTED)
        var nested_events : array<JsonValue?>
        nested_events |> click_at(0, p_nested)
        post_command(app, "imgui_mouse_play", JV((events = nested_events)))
        sleep(1500u)

        // ---- Stage 3: id= per-call sugar ----
        move_to(app, p_hashed)
        say(app, "id= mangles the ImGui hash; telemetry path unchanged.", T_HASHED)
        var hashed_events : array<JsonValue?>
        hashed_events |> click_at(0, p_hashed)
        post_command(app, "imgui_mouse_play", JV((events = hashed_events)))
        sleep(1500u)

        // ---- Stage 4: path= per-call sugar ----
        move_to(app, p_rps)
        say(app, "path= replaces the registry path leaf.", T_RPS_PATH)
        var rps_events : array<JsonValue?>
        rps_events |> drag_along(0, (rps_x0, rps_y), (rps_x1, rps_y), 1400)
        post_command(app, "imgui_mouse_play", JV((events = rps_events)))
        sleep(2000u)
    }
}
