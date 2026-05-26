options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require imgui public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Driver script: record ``input_text.apng`` against
//! ``examples/tutorial/input_text.das``. Tours six text-input forms —
//! basic, with_hint, multiline, growable, callback (TAB completion),
//! and text_filter — and drives one buffer via ``imgui_set``.

let NARRATE_FRAMES = 180        //! 6s visible at the app's 30 fps target
let READ_MS        = 3500u      //! 3.5s read window per stage
let SETTLE_MS      = 1200u      //! 1.2s cursor settle
let SET_DWELL_MS   = 1500u      //! 1.5s post-imgui_set dwell

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
    with_recording_app("examples/tutorial/input_text.das",
                       "input_text.apng", 60, 30) $(app) {
        let T_NAME   = "IT_WIN/IT_NAME"
        let T_EMAIL  = "IT_WIN/IT_EMAIL"
        let T_BIO    = "IT_WIN/IT_BIO"
        let T_FREE   = "IT_WIN/IT_FREE"
        let T_CMD    = "IT_WIN/IT_CMD"
        let T_FILTER = "IT_WIN/IT_FILTER"

        var snap = wait_for_widget(app, T_NAME, 10.0f)
        if (snap == null) {
            panic("{T_NAME} never registered — wrong app running?")
        }
        let p_name   = widget_center(snap, T_NAME)
        let p_email  = widget_center(snap, T_EMAIL)
        let p_bio    = widget_center(snap, T_BIO)
        let p_free   = widget_center(snap, T_FREE)
        let p_cmd    = widget_center(snap, T_CMD)
        let p_filter = widget_center(snap, T_FILTER)

        //! Initial cursor placement.
        move_to(app, p_name, 600)
        sleep(SETTLE_MS)

        // ---- Stage 1: basic input_text — drive a value during narration ----
        post_command(app, "imgui_set", JV((target = T_NAME, value = "Ada Lovelace")))
        sleep(SET_DWELL_MS)
        post_command(app, "imgui_narrate", JV((
            text = "input_text(IDENT, (text)) — single-line, fixed 256-byte buffer. state.value mirrors the C++ buffer each frame.",
            target = T_NAME,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 2: with_hint — set then clear to show placeholder ----
        move_to(app, p_email, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_set", JV((target = T_EMAIL, value = "ada@analytical.engine")))
        sleep(SET_DWELL_MS)
        post_command(app, "imgui_narrate", JV((
            text = "input_text_with_hint — extra 'hint' arg shows as placeholder when the buffer is empty.",
            target = T_EMAIL,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 3: multiline ----
        move_to(app, p_bio, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_set", JV((target = T_BIO, value = "Note No. 1: Charles Babbage\nNote No. 2: Analytical Engine\nNote No. 3: First algorithm")))
        sleep(SET_DWELL_MS)
        post_command(app, "imgui_narrate", JV((
            text = "input_text_multiline — CR/LF tolerant. size = (w, h); (0, 0) lets ImGui pick a default wide-short rect.",
            target = T_BIO,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 4: growable — drive payload past 256B to trigger CallbackResize ----
        move_to(app, p_free, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_set", JV((target = T_FREE,
                                           value = "The Analytical Engine has no pretensions whatever to originate anything. It can do whatever we know how to order it to perform. It can follow analysis; but it has no power of anticipating any analytical relations or truths.")))
        sleep(SET_DWELL_MS)
        post_command(app, "imgui_narrate", JV((
            text = "input_text_growable — buffer auto-resizes past state.capacity via ImGui's CallbackResize. Plumbed through a daslang lambda + stack thunk.",
            target = T_FREE,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 5: callback (TAB completion) ----
        move_to(app, p_cmd, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_set", JV((target = T_CMD, value = "cla")))
        sleep(SET_DWELL_MS)
        post_command(app, "imgui_narrate", JV((
            text = "input_text_callback — user lambda fires on flagged events. CallbackCompletion = TAB; CallbackHistory = Up/Down. data pointer valid inside the call.",
            target = T_CMD,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)

        // ---- Stage 6: text_filter ----
        move_to(app, p_filter, 800)
        sleep(SETTLE_MS)
        post_command(app, "imgui_narrate", JV((
            text = "text_filter — inline InputText editor that parses comma-separated incl,-excl tokens. Pair with passes_filter(STATE, line) to gate output.",
            target = T_FILTER,
            frames = NARRATE_FRAMES
        )))
        sleep(READ_MS)
    }
}
