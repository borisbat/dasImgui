options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``live_reload.apng``. One shell:
//!
//!     bin/Release/daslang.exe -project_root <dasimgui> \
//!         <dasimgui>/tests/integration/record_live_reload.das

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
    with_recording_app("examples/tutorial/live_reload.das",
                       "live_reload.apng", 60) $(app) {
        let T_VOLUME = "LIVE_WIN/VOLUME"
        let T_PING   = "LIVE_WIN/PING_BTN"

        var snap = wait_for_render(app, T_VOLUME, 10.0f)
        if (snap == null) {
            panic("{T_VOLUME} never rendered — wrong app running?")
        }
        let p_ping   = widget_center(snap, T_PING)
        let p_volume = widget_center(snap, T_VOLUME)

        // ---- Stage 1: VOLUME (@live slider, preserved across reload) ----
        move_to(app, p_volume)
        say(app, "VOLUME is @live — value preserved across reload.", T_VOLUME)
        post_command(app, "imgui_set", JV((target = T_VOLUME, value = 0.65f)))
        sleep(CLICK_DWELL_MS)

        // ---- Stage 2: PING button — ClickState's @live click_count ----
        move_to(app, p_ping)
        say(app, "PING_BTN.click_count is @live too.", T_PING)
        var ping_events : array<JsonValue?>
        ping_events |> click_at(0, p_ping)
        post_command(app, "imgui_mouse_play", JV((events = ping_events)))
        sleep(1200u)
        var ping_events2 : array<JsonValue?>
        ping_events2 |> click_at(0, p_ping)
        post_command(app, "imgui_mouse_play", JV((events = ping_events2)))
        sleep(CLICK_DWELL_MS)

        // ---- Stage 3: custom [live_command] — bump_counter via curl ----
        say(app, "bump_counter is a user-defined [live_command].", T_PING)
        post_command(app, "bump_counter", JV((by = 1)))
        sleep(800u)
        post_command(app, "bump_counter", JV((by = 5)))
        sleep(800u)
        post_command(app, "bump_counter", JV((by = 1)))
        sleep(CLICK_DWELL_MS)

        // ---- Stage 4: reset_counter — same surface, different handler ----
        say(app, "reset_counter — same surface, app-defined endpoint.", T_PING)
        post_command(app, "reset_counter", null)
        sleep(CLICK_DWELL_MS)
    }
}
