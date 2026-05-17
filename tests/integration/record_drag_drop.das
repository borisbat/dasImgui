options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``drag_drop.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_drag_drop.das

//! Reader pacing locked per skills/recording.md.
let NARRATE_FRAMES = 240
let READ_MS    = 5000u
let SETTLE_MS  = 1500u
let RESULT_MS  = 2000u
let TAIL_MS    = 1500u   //! cushion after final narrate so record_stop doesn't cut the last frame

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
    with_recording_app("examples/features/drag_drop.das",
                       "drag_drop.apng", 45) $(app) {
        let T_SOURCE = "MAIN_WIN/SOURCE_BTN"
        let T_TARGET = "MAIN_WIN/TARGET_BTN"

        var snap = wait_for_render(app, T_SOURCE, 10.0f)
        if (snap == null) {
            panic("{T_SOURCE} never rendered -- wrong app running?")
        }
        let p_source = widget_center(snap, T_SOURCE)
        let p_target = widget_center(snap, T_TARGET)

        //! Initial cursor placement (synth IO flips `cursor_owned` on first move).
        move_to(app, (360.0f, 360.0f), 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: hover SOURCE + narrate ----
        move_to(app, p_source, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "drag_drop_source attaches to the SOURCE button.",
            target = T_SOURCE,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: hover TARGET + narrate ----
        move_to(app, p_target, 900)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "drag_drop_target accepts the typed payload.",
            target = T_TARGET,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 3: perform the drag ----
        //! Use drag_along + imgui_mouse_play (not drag_to). drag_to dispatches
        //! the L1 drag coroutine which calls AddMouseButtonEvent / AddMousePosEvent
        //! directly on io; that races against imgui_synth_tick's per-frame cursor
        //! re-assertion and the press never appears to "hold." Building synth
        //! events and posting via imgui_mouse_play routes through the synth
        //! pipeline (synth_held_buttons + synth_cursor) which IS the drained path.
        post_command(app, "imgui_narrate", JV((
            text = "drag from SOURCE bbox to TARGET bbox -- payload travels with the cursor.",
            target = T_SOURCE,
            frames = NARRATE_FRAMES
        )))
        sleep(RESULT_MS)
        var drag_events : array<JsonValue?>
        drag_events |> drag_along(0, p_source, p_target, 1200, 400)
        post_command(app, "imgui_mouse_play", JV((events = drag_events)))
        sleep(uint(2200))   //! approach(400) + 100 + drag(1200) + 200 + 300 = 2200ms wall time
        sleep(RESULT_MS)
        //! Settle on the target so the reader sees "Drops accepted: 1".
        sleep(TAIL_MS)
    }
}
