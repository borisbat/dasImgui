options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``color_button_hover.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_color_button_hover.das

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
    with_recording_app("examples/tutorial/color_button_hover.das",
                       "color_button_hover.apng", 40) $(app) {
        let T_RED    = "CBH_WIN/CBH_RED"
        let T_GREEN  = "CBH_WIN/CBH_GREEN"
        let T_BLUE   = "CBH_WIN/CBH_BLUE"
        let T_STATUS = "CBH_WIN/CBH_STATUS"

        var snap = wait_for_render(app, T_RED, 10.0f)
        if (snap == null) {
            panic("{T_RED} never rendered — wrong app running?")
        }
        let p_red    = widget_center(snap, T_RED)
        let p_green  = widget_center(snap, T_GREEN)
        let p_blue   = widget_center(snap, T_BLUE)
        let p_status = widget_center(snap, T_STATUS)

        // ---- Stage 1: hover red ----
        move_to(app, p_red)
        say(app, "color_button_hover returns true while ImGui considers the swatch hovered.", T_RED)

        // ---- Stage 2: hover green ----
        move_to(app, p_green)
        say(app, "Move to a new swatch — the return-bool follows the cursor.", T_GREEN)

        // ---- Stage 3: hover blue ----
        move_to(app, p_blue)
        say(app, "No click bookkeeping — pure hover surface.", T_BLUE)

        // ---- Stage 4: highlight the status text ----
        move_to(app, p_status)
        say(app, "STATE_MESSAGE updates per-frame from each swatch's hover bool.", T_STATUS)
    }
}
