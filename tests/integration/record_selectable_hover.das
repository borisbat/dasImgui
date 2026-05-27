options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``selectable_hover.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_selectable_hover.das

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
    with_recording_app("examples/tutorial/selectable_hover.das",
                       "selectable_hover.apng", 50) $(app) {
        let T_ROW0   = "SH_WIN/SH_ROW[0]"
        let T_ROW2   = "SH_WIN/SH_ROW[2]"
        let T_ROW4   = "SH_WIN/SH_ROW[4]"
        let T_STATUS = "SH_WIN/SH_STATUS"

        var snap = wait_for_render(app, T_ROW0, 10.0f)
        if (snap == null) {
            panic("{T_ROW0} never rendered — wrong app running?")
        }
        let p_row0   = widget_center(snap, T_ROW0)
        let p_row2   = widget_center(snap, T_ROW2)
        let p_row4   = widget_center(snap, T_ROW4)
        let p_status = widget_center(snap, T_STATUS)

        // ---- Stage 1: hover first row ----
        move_to(app, p_row0)
        say(app, "selectable_hover pins selected=false and returns hover bool.", T_ROW0)

        // ---- Stage 2: hover middle row ----
        move_to(app, p_row2)
        say(app, "Move down the list — STATE_MESSAGE follows the hover.", T_ROW2)

        // ---- Stage 3: hover last row ----
        move_to(app, p_row4)
        say(app, "No toggle, no persisted selection — pure hover row.", T_ROW4)

        // ---- Stage 4: focus the status line ----
        move_to(app, p_status)
        say(app, "STATE_MESSAGE updates per-frame from each row's hover bool.", T_STATUS)
    }
}
