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
//!
//! Each of the three SetNextWindowSizeConstraints callbacks
//! (square / aspect 16:9 / step-50) reshapes the requested size. The
//! recorder demonstrates this by REQUESTING odd sizes via the new
//! ``resize_window(app, target, w, h)`` helper and showing the
//! callback snap the result. resize_window routes through the new
//! ``imgui_set_window_size`` live_command which calls
//! ``SetNextWindowSize(pending_size, ImGuiCond.Always)`` next frame.

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
                       "window_size_constraints.apng", 60) $(app) {
        let T_SQUARE_WIN = "SQUARE_WIN"
        let T_ASPECT_WIN = "ASPECT_WIN"
        let T_STEP_WIN   = "STEP_WIN"
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

        // ---- Stage 1: Square — request a wide rectangle; callback forces it square ----
        move_to(app, p_square)
        sleep(SETTLE_MS)
        say(app, "Square — request 400×180 via resize_window; the callback runs max(w,h) on both dims and forces 400×400 instead.", T_SQUARE)
        resize_window(app, T_SQUARE_WIN, 400.0f, 180.0f)
        sleep(CLICK_DWELL_MS)
        say(app, "Body line shows the snapped size. Even though we asked for 180-tall, the callback bumped height to match the larger width.", T_SQUARE)

        // ---- Stage 2: Aspect 16:9 — request a non-aspect-correct size ----
        move_to(app, p_aspect)
        sleep(SETTLE_MS)
        say(app, "Aspect 16:9 — request 480×400 via resize_window; the callback forces height = width / (16:9) = 270.", T_ASPECT)
        resize_window(app, T_ASPECT_WIN, 480.0f, 400.0f)
        sleep(CLICK_DWELL_MS)
        say(app, "Body line reads ~480 × 270. The capture-by-value `ratio` lambda preserves the constraint across every resize.", T_ASPECT)

        // ---- Stage 3: Step 50 — request off-grid size; callback snaps to 50px grid ----
        move_to(app, p_step)
        sleep(SETTLE_MS)
        say(app, "Step 50 — request 333×217 via resize_window; both dims snap to the nearest 50: 350 × 200.", T_STEP)
        resize_window(app, T_STEP_WIN, 333.0f, 217.0f)
        sleep(CLICK_DWELL_MS)
        say(app, "Both dims snap independently. The step is captured into the lambda, so each window's callback owns its own grid spacing.", T_STEP)
    }
}
