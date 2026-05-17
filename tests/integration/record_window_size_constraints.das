options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``window_size_constraints.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_window_size_constraints.das

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
    with_recording_app("examples/tutorial/window_size_constraints.das",
                       "window_size_constraints.apng", 30) $(app) {
        let T_SQUARE = "SQUARE_WIN/SQUARE_TEXT"
        let T_ASPECT = "ASPECT_WIN/ASPECT_TEXT"
        let T_STEP   = "STEP_WIN/STEP_TEXT"

        var snap = wait_for_render(app, T_SQUARE, 10.0f)
        if (snap == null) {
            panic("{T_SQUARE} never rendered — wrong app running?")
        }
        let p_square = widget_center(snap, T_SQUARE)
        let p_aspect = widget_center(snap, T_ASPECT)
        let p_step   = widget_center(snap, T_STEP)

        // ---- Stage 1: square window ----
        post_command(app, "imgui_narrate", JV((
            text = "Square — max(w,h) wins both dims.",
            target = T_SQUARE,
            frames = 180
        )))
        move_to(app, p_square)
        sleep(3500u)

        // ---- Stage 2: aspect 16:9 ----
        post_command(app, "imgui_narrate", JV((
            text = "Aspect 16:9 — height tracks width / 16:9.",
            target = T_ASPECT,
            frames = 180
        )))
        move_to(app, p_aspect)
        sleep(3500u)

        // ---- Stage 3: fixed step 50 ----
        post_command(app, "imgui_narrate", JV((
            text = "Step 50 — both dims snap to nearest 50 px.",
            target = T_STEP,
            frames = 180
        )))
        move_to(app, p_step)
        sleep(3500u)
    }
}
