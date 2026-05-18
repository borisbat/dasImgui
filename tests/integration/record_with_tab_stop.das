options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``with_tab_stop.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_with_tab_stop.das

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
    with_recording_app("examples/tutorial/with_tab_stop.das",
                       "with_tab_stop.apng", 30) $(app) {
        let T_A    = "TS_WIN/TS_FIELD_A"
        let T_B    = "TS_WIN/TS_FIELD_B"
        let T_SKIP = "TS_WIN/TS_FIELD_SKIP"
        let T_C    = "TS_WIN/TS_FIELD_C"
        let T_D    = "TS_WIN/TS_FIELD_D"

        var snap = wait_for_render(app, T_A, 10.0f)
        if (snap == null) {
            panic("{T_A} never rendered — wrong app running?")
        }
        let p_a    = widget_center(snap, T_A)
        let p_b    = widget_center(snap, T_B)
        let p_skip = widget_center(snap, T_SKIP)
        let p_c    = widget_center(snap, T_C)
        let p_d    = widget_center(snap, T_D)

        // ---- Stage 1: TAB visits Field A → B ----
        post_command(app, "imgui_narrate", JV((
            text = "Field A — TAB advances to Field B (regular tab-stop).",
            target = T_A,
            frames = 180
        )))
        move_to(app, p_a)
        sleep(3500u)

        post_command(app, "imgui_narrate", JV((
            text = "Field B — next on the TAB chain.",
            target = T_B,
            frames = 180
        )))
        move_to(app, p_b)
        sleep(3500u)

        // ---- Stage 2: with_tab_stop(false) — middle field skipped ----
        post_command(app, "imgui_narrate", JV((
            text = "Wrapped in with_tab_stop(false) — TAB skips this field.",
            target = T_SKIP,
            frames = 200
        )))
        move_to(app, p_skip)
        sleep(3500u)

        // ---- Stage 3: TAB resumes on Field C → D ----
        post_command(app, "imgui_narrate", JV((
            text = "Field C — TAB jumped here, past the wrapped block.",
            target = T_C,
            frames = 180
        )))
        move_to(app, p_c)
        sleep(3500u)

        post_command(app, "imgui_narrate", JV((
            text = "Field D — tab-stop cycle resumes normally.",
            target = T_D,
            frames = 180
        )))
        move_to(app, p_d)
        sleep(3500u)
    }
}
