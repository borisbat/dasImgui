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
//!
//! Demonstrates with_tab_stop(false) by FOCUSING field A and then
//! pressing TAB three times: A→B, B skips SKIP and lands on C, C→D.
//! The viewer sees the active-input glow jump fields visibly — the
//! whole point of with_tab_stop is that the SKIP field is bypassed.

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
                       "with_tab_stop.apng", 50) $(app) {
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

        // ---- Stage 1: focus Field A ----
        move_to(app, p_a)
        sleep(SETTLE_MS)
        focus(app, T_A)
        sleep(CLICK_DWELL_MS)
        say(app, "Focus on Field A — TAB advances to Field B (regular tab-stop).", T_A)

        // ---- Stage 2: TAB → Field B ----
        move_to(app, p_b)
        sleep(SETTLE_MS)
        key_tap(app, int(ImGuiKey.Tab))
        sleep(CLICK_DWELL_MS)
        say(app, "TAB pressed — Field B is now focused. Both A and B are inside the regular tab chain.", T_B)

        // ---- Stage 3: TAB → SKIPS SKIP → lands on C ----
        move_to(app, p_skip)
        sleep(SETTLE_MS)
        key_tap(app, int(ImGuiKey.Tab))
        sleep(CLICK_DWELL_MS)
        say(app, "TAB pressed again — SKIP is wrapped in with_tab_stop(false), so focus jumps past it directly to Field C.", T_SKIP)

        // ---- Stage 4: TAB → Field D ----
        move_to(app, p_c)
        sleep(SETTLE_MS)
        say(app, "Field C now has the active-input glow. One more TAB advances to D, completing the cycle past the skipped field.", T_C)

        move_to(app, p_d)
        sleep(SETTLE_MS)
        key_tap(app, int(ImGuiKey.Tab))
        sleep(CLICK_DWELL_MS)
        say(app, "Field D — tab-stop cycle resumes normally after the wrapped block.", T_D)
    }
}
