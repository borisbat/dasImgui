options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``plot.apng`` against
//! ``examples/tutorial/plot.das``. Tours four sample-plot widgets — two
//! array-form (plot_lines / plot_histogram) and two lambda-form
//! (plot_lines_getter / plot_histogram_getter). The subject's
//! ``g_phase`` advances per frame so the sine waves animate during
//! narration — read time naturally shows the motion.

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
    with_recording_app("examples/tutorial/plot.das",
                       "plot.apng", 40) $(app) {
        let T_LINES   = "PL_WIN/PL_LINES"
        let T_HIST    = "PL_WIN/PL_HIST"
        let T_LINES_G = "PL_WIN/PL_LINES_G"
        let T_HIST_G  = "PL_WIN/PL_HIST_G"

        var snap = wait_for_widget(app, T_LINES, 10.0f)
        if (snap == null) {
            panic("{T_LINES} never registered — wrong app running?")
        }
        let p_lines   = widget_center(snap, T_LINES)
        let p_hist    = widget_center(snap, T_HIST)
        let p_lines_g = widget_center(snap, T_LINES_G)
        let p_hist_g  = widget_center(snap, T_HIST_G)

        //! Initial cursor placement.
        move_to(app, p_lines, 500)
        sleep(SETTLE_MS)

        // ---- Stage 1: plot_lines (array) ----
        say(app, "plot_lines (array form) — pass per-frame array<float>; ImGui copies synchronously. Explicit scale_min / scale_max avoids per-frame autoscale jitter.", T_LINES)

        // ---- Stage 2: plot_histogram (array) ----
        move_to(app, p_hist, 800)
        sleep(SETTLE_MS)
        say(app, "plot_histogram (array form) — same shape as plot_lines, bars instead of polyline. PlotState records title + samples for snapshot.", T_HIST)

        // ---- Stage 3: plot_lines_getter (lambda) ----
        move_to(app, p_lines_g, 800)
        sleep(SETTLE_MS)
        say(app, "plot_lines_getter (lambda) — callback (idx) : float fires once per sample, synchronously inside the C call. Skips the backing array; great for synthesized signals.", T_LINES_G)

        // ---- Stage 4: plot_histogram_getter (lambda) ----
        move_to(app, p_hist_g, 800)
        sleep(SETTLE_MS)
        say(app, "plot_histogram_getter (lambda) — bars from a lambda. Same use-case as plot_lines_getter; pick by visualization style.", T_HIST_G)
    }
}
