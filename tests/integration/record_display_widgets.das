options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``display_widgets.apng`` against
//! ``examples/tutorial/display_widgets.das``. The tutorial renders three
//! ``progress_bar`` calls and two ``image`` calls inside ``DISPLAY_WIN``.
//! None of the inner widgets carry an ident (they're [widget]-auto-instanced
//! anonymously), so the only routable path is the window itself —
//! the cursor settles over the window center and narrate is anchored to it
//! while the sine-driven middle bar animates across the recording.

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
    with_recording_app("examples/tutorial/display_widgets.das",
                       "display_widgets.apng", 45) $(app) {
        var snap = wait_for_render(app, "DISPLAY_WIN", 10.0f)
        if (snap == null) {
            panic("DISPLAY_WIN never rendered — wrong app running?")
        }
        let p_win = widget_center(snap, "DISPLAY_WIN")

        //! Initial cursor placement to flip synth_cursor_owned.
        move_to(app, p_win, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: progress_bar overview ----
        say(app, "progress_bar wraps ImGui::ProgressBar — fraction + size + overlay text. Three calls stacked: static 33%, sine-driven, fixed-width with custom overlay.", "DISPLAY_WIN")

        // ---- Stage 2: middle bar animation ----
        say(app, "The middle bar's fraction is driven by sin(phase) — the snapshot's ProgressBarState.fraction follows the visible bar exactly.", "DISPLAY_WIN")

        // ---- Stage 3: image overview ----
        say(app, "image wraps ImGui::Image — uv0/uv1 + tint_col + border_col. Both samples use the ImGui font atlas texture; the second one tints green with a half-alpha border.", "DISPLAY_WIN")

        // ---- Stage 4: snapshot path note ----
        say(app, "Inner widgets are anonymous — only DISPLAY_WIN registers a path in the snapshot. The render proves the widgets fired; per-call state lives in the [widget]'s ImageState / ProgressBarState payload.", "DISPLAY_WIN")
    }
}
