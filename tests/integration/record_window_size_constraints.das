options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``window_size_constraints.apng`` against
//! ``examples/tutorial/window_size_constraints.das``. Three voiced,
//! self-verifying beats — each drags a window's resize grip (the REAL
//! "drag border" gesture the tutorial teaches, NOT a programmatic
//! resize) to an off-constraint shape and asserts the callback snapped
//! the window to the exact constrained size:
//!   1. Square      — drag to 400x180; max(w,h) forces 400x400.
//!   2. Aspect 16:9 — drag to 480x400; height tracks width/ratio -> 480x270.
//!   3. Step 50     — drag to 333x217; both dims snap to 350x200.
//! The grip is the window's bottom-right corner (pos + size); ImGui zeroes
//! a window's reported bbox, so grip/target are computed from the payload's
//! pos + size. Disabling imgui.ini persistence (live_imgui_init) keeps the
//! FirstUseEver layout deterministic across runs.

def win_pos(var snap : JsonValue?; ident : string) : float2 {
    let p = snap?["globals"]?[ident]?["payload"]?["pos"]
    return float2(p?["x"] ?? 0.0f, p?["y"] ?? 0.0f)
}

def win_size(var snap : JsonValue?; ident : string) : float2 {
    let s = snap?["globals"]?[ident]?["payload"]?["size"]
    return float2(s?["x"] ?? 0.0f, s?["y"] ?? 0.0f)
}

def win_grip(var snap : JsonValue?; ident : string) : tuple<float; float> {
    let p = win_pos(snap, ident)
    let s = win_size(snap, ident)
    return (p.x + s.x, p.y + s.y)
}

def win_corner(var snap : JsonValue?; ident : string; req : float2) : tuple<float; float> {
    let p = win_pos(snap, ident)
    return (p.x + req.x, p.y + req.y)
}

//! Drag ``win``'s grip to ``corner`` UNDER an already-posted voice line, then
//! assert the constraint callback snapped ``win`` to ``expected``. The caller
//! has already move_to'd the grip and posted say_begin (whose dwell is passed
//! here) — mirrors hold_through_voice / drag_through_voice's split so
//! prepare_recording can scan the literal say lines at the call site.
def drag_under_voice(app : ImguiApp; dwell : uint; win : string;
                     grip : tuple<float; float>; corner : tuple<float; float>;
                     expected : float2) {
    let lead = dwell > 1200u ? 700u : dwell / 3u
    sleep(lead)
    var ev : array<JsonValue?>
    ev |> drag_along(0, grip, corner, 900, 200)
    post_command(app, "imgui_mouse_play", JV((events = ev)))
    unsafe { delete ev; }
    let play = uint(200 + 300 + 900) + 400u   // drag_along timeline + settle
    sleep(play)
    record_check_value(app, win, "size", expected, 180)
    let consumed = lead + play
    sleep(dwell > consumed ? dwell - consumed : 0u)
}

[export]
def main {
    with_recording_app("examples/tutorial/window_size_constraints.das",
                       "window_size_constraints.apng", 55) $(app) {
        let T_SQUARE = "SQUARE_WIN/SQUARE_TEXT"
        let T_ASPECT = "ASPECT_WIN/ASPECT_TEXT"
        let T_STEP   = "STEP_WIN/STEP_TEXT"

        var snap = wait_for_render(app, T_SQUARE, 10.0f)
        if (snap == null) {
            panic("{T_SQUARE} never rendered - wrong app running?")
        }

        // Warm up the capture pipeline before the first voice. The cold-start
        // frames render at a lower fps; counting them under the first beat skews
        // convert's single frame->time mapping and can crowd the first two
        // captions together (voice overlap). A brief settled intro absorbs them.
        move_to(app, (200.0f, 120.0f), 800)
        sleep(1800u)

        // ---- Beat 1: Square — max(w, h) wins both dims ----
        var s1 = snapshot(app)
        let g1 = win_grip(s1, "SQUARE_WIN")
        let c1 = win_corner(s1, "SQUARE_WIN", float2(400.0, 180.0))
        move_to(app, g1, 800)
        sleep(SETTLE_MS)
        drag_under_voice(app, say_begin(app, "always square (max of w, h)", T_SQUARE,
            [voice = "Drag this window to a wide, short shape, and the callback snaps it straight back to a perfect square."]),
            "SQUARE_WIN", g1, c1, float2(400.0, 400.0))

        // ---- Beat 2: Aspect 16:9 — height tracks width / ratio ----
        var s2 = snapshot(app)
        let g2 = win_grip(s2, "ASPECT_WIN")
        let c2 = win_corner(s2, "ASPECT_WIN", float2(480.0, 400.0))
        move_to(app, g2, 800)
        sleep(SETTLE_MS)
        drag_under_voice(app, say_begin(app, "locked to 16:9", T_ASPECT,
            [voice = "The second window locks to sixteen by nine. Drag it tall, and the height snaps back to match the width."]),
            "ASPECT_WIN", g2, c2, float2(480.0, 270.0))

        // ---- Beat 3: Step 50 — both dims snap to the nearest 50 px ----
        var s3 = snapshot(app)
        let g3 = win_grip(s3, "STEP_WIN")
        let c3 = win_corner(s3, "STEP_WIN", float2(333.0, 217.0))
        move_to(app, g3, 800)
        sleep(SETTLE_MS)
        drag_under_voice(app, say_begin(app, "snaps to a 50px grid", T_STEP,
            [voice = "The third snaps to a grid. Drag it anywhere off-grid, and both sides jump to the nearest fifty pixels."]),
            "STEP_WIN", g3, c3, float2(350.0, 200.0))
    }
}
