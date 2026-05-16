options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module imgui_playwright public

require imgui/imgui_transport public
require dashv/dashv_boost public
require daslib/json public
require daslib/json_boost public
require daslib/fio public
require daslib/command_line
require daslib/clargs
require daslib/strings_boost
require strings

// Module overview lives in handmade/module-imgui_playwright.rst.

// ===== Tunables =====

let DEFAULT_LIVE_PORT : int = 9090                   // daslang-live's live_api default port
let DEFAULT_DEADLOCK_SANITY_SEC : float = 120.0f     // backstop for the frame-counter-never-advances case (crash / true deadlock); never trips on slow-but-progressing
let DEFAULT_READY_TIMEOUT_SEC : float = 30.0f        // /status must turn 200 OK within this — covers daslang-live boot + GLFW + ImGui ctx
let DEFAULT_TEST_TIMEOUT_SEC : float = 120.0f        // upper bound on the entire popen lifetime, including body + drain
let DEFAULT_RELOAD_TIMEOUT_SEC : float = 30.0f       // POST /reload to /status.has_error == false convergence
let DEFAULT_FRAME_WAIT_SEC : float = 10.0f           // upper bound on "first frame to render the named widget"

let READY_POLL_INTERVAL_MS : uint = 100u             // ms between /status polls — wait_until_ready and reload convergence
let FRAME_POLL_INTERVAL_MS : uint = 50u              // ms between snapshot polls — ~3 polls/frame at 60fps

struct ImguiApp {
    base_url : string
    feature_path : string
    transport : Transport
}

// ===== Driver-side mouse helpers (record_*.das) =====
//
// Tutorial drivers script smooth cursor motion via ``imgui_mouse_play``.
// The host's ``advance_mouse_timeline`` (imgui_live_core) interpolates
// linearly between adjacent move waypoints with distinct ``t_ms``, so we
// only get visible cursor travel + a useful mouse trail when each call
// emits at least two move events spanning a real time window.
//
// We track the previous cursor target in a module-scope pair so each
// helper can lerp from there to the next target without the driver
// having to thread the state by hand.

var private last_cursor_x : float = 0.0f
var private last_cursor_y : float = 0.0f

def public reset_cursor_pos(pos : tuple<float; float> = (0.0f, 0.0f)) {
    //! Reset the tracked previous cursor position. Call between recordings
    //! if the host's synth cursor state was already non-(0,0).
    last_cursor_x = pos._0
    last_cursor_y = pos._1
}

def public move_to(app : ImguiApp; pos : tuple<float; float>; duration_ms : int = 600) {
    //! Post a lerped cursor move from the last tracked position to ``pos``
    //! over ``duration_ms``, with a brief dwell pin afterwards. Updates the
    //! tracked position.
    var events <- [
        JV((t_ms = 0,                 kind = "move", x = last_cursor_x, y = last_cursor_y)),
        JV((t_ms = duration_ms,       kind = "move", x = pos._0,        y = pos._1)),
        JV((t_ms = duration_ms + 300, kind = "move", x = pos._0,        y = pos._1))
    ]
    post_command(app, "imgui_mouse_play", JV((events = events)))
    last_cursor_x = pos._0
    last_cursor_y = pos._1
}

def public click_at(var events : array<JsonValue?>;
                    t_ms : int;
                    pos : tuple<float; float>;
                    travel_ms : int = 500;
                    button : int = 0) {
    //! Append lerp-from-last + press + release + dwell to ``events``.
    //! Cursor travels from the tracked previous position to ``pos`` over
    //! ``travel_ms``, then mouse button ``button`` is pressed and released.
    //! Updates the tracked position.
    events |> push(JV((t_ms = t_ms,                   kind = "move",   x = last_cursor_x, y = last_cursor_y)))
    events |> push(JV((t_ms = t_ms + travel_ms,       kind = "move",   x = pos._0,        y = pos._1)))
    events |> push(JV((t_ms = t_ms + travel_ms + 200, kind = "button", button = button,   action = "press")))
    events |> push(JV((t_ms = t_ms + travel_ms + 300, kind = "button", button = button,   action = "release")))
    events |> push(JV((t_ms = t_ms + travel_ms + 500, kind = "move",   x = pos._0,        y = pos._1)))
    last_cursor_x = pos._0
    last_cursor_y = pos._1
}

def public drag_along(var events : array<JsonValue?>;
                      t_ms : int;
                      from_pos : tuple<float; float>;
                      to_pos : tuple<float; float>;
                      drag_ms : int;
                      approach_ms : int = 400;
                      button : int = 0) {
    //! Append lerp-to-start + press + drag + release + dwell to ``events``.
    //! Cursor first travels from the tracked previous position to
    //! ``from_pos`` over ``approach_ms``, then presses and drags to
    //! ``to_pos`` over ``drag_ms``. Updates the tracked position to
    //! ``to_pos``.
    events |> push(JV((t_ms = t_ms,                                kind = "move",   x = last_cursor_x, y = last_cursor_y)))
    events |> push(JV((t_ms = t_ms + approach_ms,                  kind = "move",   x = from_pos._0,   y = from_pos._1)))
    events |> push(JV((t_ms = t_ms + approach_ms + 100,            kind = "button", button = button,   action = "press")))
    events |> push(JV((t_ms = t_ms + approach_ms + 100 + drag_ms,  kind = "move",   x = to_pos._0,     y = to_pos._1)))
    events |> push(JV((t_ms = t_ms + approach_ms + 200 + drag_ms,  kind = "button", button = button,   action = "release")))
    events |> push(JV((t_ms = t_ms + approach_ms + 300 + drag_ms,  kind = "move",   x = to_pos._0,     y = to_pos._1)))
    last_cursor_x = to_pos._0
    last_cursor_y = to_pos._1
}

def private daslang_live_exe() : string {
    let das = get_das_exe()
    if (empty(das)) return ""
    let dir = dir_name(das)
    let bin = get_platform_name() == "windows" ? "daslang-live.exe" : "daslang-live"
    return path_join(dir, bin)
}

def private resolve_feature_path(path : string) : string {
    if (is_absolute(path)) return path
    return path_join(get_das_root(), path)
}

def public wait_until_ready(app : ImguiApp; timeout_sec : float) : bool {
    //! Poll GET /status until 200 OK or timeout. Returns true on ready.
    // `ref_time_ticks()` is platform-specific (QPC on Windows, nanoseconds on
    // Linux/macOS), so absolute-deadline arithmetic with `* 1_000_000` is wrong
    // on POSIX (gives 30 ms instead of 30 s). `get_time_usec(start)` is the
    // portable elapsed-microseconds helper.
    let start = ref_time_ticks()
    let timeout_usec = int(timeout_sec * 1000000.0f)
    while (get_time_usec(start) < timeout_usec) {
        var ok = false
        GET("{app.base_url}/status") $(resp) {
            if (resp != null && resp.status_code == http_status.OK) {
                ok = true
            }
        }
        if (ok) return true
        sleep(READY_POLL_INTERVAL_MS)
    }
    return false
}

def public get_text(app : ImguiApp; uri : string) : string {
    //! GET `uri`; return the raw response body or "".
    var out : string
    GET("{app.base_url}{uri}") $(resp) {
        if (resp != null) {
            out = string(resp.body)
        }
    }
    return out
}

def private post_signal(app : ImguiApp; uri : string) {
    POST("{app.base_url}{uri}", "", {"Content-Type" => "application/json"}) $(resp) {
        // intentionally drop the response — caller polled /status to confirm
    }
}

// ===== Command dispatch =====

def public post_command(app : ImguiApp; name : string; var args : JsonValue?) : JsonValue? {
    //! Send ``{"name":<name>,"args":<args>}`` through ``app.transport``; returns parsed JSON or null on transport failure.
    //! Escape hatch for custom verbs outside the shipped helper set.
    return send_imgui_command(app.transport, name, args)
}

def public snapshot(app : ImguiApp) : JsonValue? {
    //! Fetch the full widget snapshot (``imgui_snapshot`` command) as a parsed ``JsonValue``.
    return send_imgui_command(app.transport, "imgui_snapshot", null)
}

// ===== Snapshot navigation =====

def public find_widget(var snap : JsonValue?; ident : string) : JsonValue? {
    //! Navigate to ``snapshot.globals[ident]``; may return a ``JV(null)`` placeholder for missing keys (daslib/json ``?[]`` quirk).
    //! For an existence check use ``widget_exists``.
    return snap?["globals"]?[ident]
}

def public widget_exists(var snap : JsonValue?; ident : string) : bool {
    //! True iff ``globals[ident]`` is a real widget entry — works around the daslib/json ``?[]`` quirk by checking the always-present ``kind`` field.
    let kind = snap?["globals"]?[ident]?["kind"] ?? ""
    return !empty(kind)
}

def public widget_payload_field(var snap : JsonValue?; ident : string; field : string) : JsonValue? {
    //! Navigate to ``snapshot.globals[ident].payload[field]``; returns null if any link is missing.
    return snap?["globals"]?[ident]?["payload"]?[field]
}

def public widget_rendered(var snap : JsonValue?; ident : string) : bool {
    //! True iff ``globals[ident]`` is for a widget that painted this frame.
    //! Registered-but-not-yet-painted entries carry ``"rendered": false``; rendered widgets omit the field (``?? true`` covers absent).
    return snap?["globals"]?[ident]?["rendered"] ?? true
}

// ===== Poll-until family =====

def public wait_until_sec(app : ImguiApp;
                          timeout_sec : float;
                          pred : block<(var snap : JsonValue?) : bool>) : JsonValue? {
    //! Wall-clock variant of ``wait_until``: poll ``pred(snap)`` until it returns true,
    //! up to ``timeout_sec`` real seconds. Returns the matching snapshot or null on timeout.
    //! Prefer this over ``wait_until`` for tests gated on time-driven server work
    //! (timeline completion, fixed-duration animations) — the frame-budget form fires
    //! prematurely in headless mode where server frames run at multi-kHz with no vsync.
    let start = ref_time_ticks()
    let timeout_usec = int(timeout_sec * 1000000.0f)
    while (get_time_usec(start) < timeout_usec) {
        var snap = snapshot(app)
        if (snap != null && invoke(pred, snap)) return snap
        sleep(FRAME_POLL_INTERVAL_MS)
    }
    return null
}

def public wait_until(app : ImguiApp;
                      max_frames : int;
                      pred : block<(var snap : JsonValue?) : bool>) : JsonValue? {
    //! Poll ``pred(snap)`` up to ``max_frames`` 60 fps-equivalent server frames (``max_frames/60`` seconds).
    //! Returns the matching snapshot or null on timeout.
    //!
    //! The legacy semantics treated ``max_frames`` as "server frame counter delta", which fired
    //! prematurely under headless: the server advances ``g_frame`` at multi-kHz, so ``max_frames=240``
    //! could expire in ~24 ms — far short of any time-driven server work (timeline completion,
    //! fixed-duration animations, ImGui state convergence). The translation to wall-clock at the
    //! conventional 60 fps preserves the headed-mode budget every test was tuned against, without
    //! the per-mode skew. For new code that's natively expressed in seconds, prefer ``wait_until_sec``.
    return wait_until_sec(app, float(max_frames) / 60.0f, pred)
}

def public wait_for_widget(app : ImguiApp; widget_ident : string;
                           timeout_sec : float = DEFAULT_FRAME_WAIT_SEC) : JsonValue? {
    //! Poll snapshot until ``globals[widget_ident]`` is present (registered at module init OR rendered at least once).
    //! Use for subprocess-startup gating; for first-paint semantics use ``wait_for_render``.
    let start = ref_time_ticks()
    let timeout_usec = int(timeout_sec * 1000000.0f)
    while (get_time_usec(start) < timeout_usec) {
        var snap = snapshot(app)
        if (snap != null && widget_exists(snap, widget_ident)) return snap
        sleep(FRAME_POLL_INTERVAL_MS)
    }
    return null
}

def public wait_for_render(app : ImguiApp; widget_ident : string;
                           timeout_sec : float = DEFAULT_FRAME_WAIT_SEC) : JsonValue? {
    //! Poll snapshot until ``globals[widget_ident]`` reports ``rendered:true`` (the widget painted this frame).
    //! Use when you specifically need first-paint semantics — registered-but-not-rendered widgets pass ``wait_for_widget`` immediately.
    let start = ref_time_ticks()
    let timeout_usec = int(timeout_sec * 1000000.0f)
    while (get_time_usec(start) < timeout_usec) {
        var snap = snapshot(app)
        if (snap != null && widget_rendered(snap, widget_ident)) return snap
        sleep(FRAME_POLL_INTERVAL_MS)
    }
    return null
}

def public wait_for_int_value(app : ImguiApp;
                              target : string;
                              field : string;
                              expected : int;
                              max_frames : int = 300) : bool {
    //! Poll snapshot until `globals[target].payload[field] == expected` (typed int).
    //! Returns true on match, false after `max_frames` frames elapse.
    return wait_until(app, max_frames) $(var snap) {
        return (widget_payload_field(snap, target, field) ?? (expected ^ 1)) == expected
    } != null
}

def public wait_for_bool_value(app : ImguiApp;
                               target : string;
                               field : string;
                               expected : bool;
                               max_frames : int = 300) : bool {
    //! Poll snapshot until `globals[target].payload[field] == expected` (typed bool).
    return wait_until(app, max_frames) $(var snap) {
        return (widget_payload_field(snap, target, field) ?? !expected) == expected
    } != null
}

def public wait_for_string_value(app : ImguiApp;
                                 target : string;
                                 field : string;
                                 expected : string;
                                 max_frames : int = 300) : bool {
    //! Poll snapshot until `globals[target].payload[field] == expected` (typed string).
    return wait_until(app, max_frames) $(var snap) {
        return (widget_payload_field(snap, target, field) ?? "") == expected
    } != null
}

def public wait_for_payload_value(app : ImguiApp;
                                  target : string;
                                  field : string;
                                  expected : auto(T);
                                  max_frames : int = 300) : bool {
    //! Generic poll: snapshot until ``globals[target].payload[field] == expected``; ``T`` is inferred from ``expected``.
    //! Use for any roundtrippable type (float2/3/4, int2/3/4, etc.) where the typed sugars above don't apply.
    return wait_until(app, max_frames) $(var snap) {
        let v = widget_payload_field(snap, target, field)
        return v != null && from_JV(v, type<typedecl(expected)>, default<typedecl(expected)>) == expected  // nolint:STYLE020 — template handles vec types where `??` isn't defined
    } != null
}

// ===== Assertions (panic on timeout) =====

def public expect_value(app : ImguiApp;
                        target : string;
                        field : string;
                        expected : auto(T);
                        max_frames : int = 300) : void {
    //! Assertion form of ``wait_for_payload_value``; panics with a focused want/got/kind/rendered message on timeout.
    if (wait_for_payload_value(app, target, field, expected, max_frames)) return
    var snap = snapshot(app)
    let got_jv = widget_payload_field(snap, target, field)
    let got_str = got_jv != null ? write_json(got_jv) : "<missing>"
    let kind = snap?["globals"]?[target]?["kind"] ?? "<unknown>"
    let exists = widget_exists(snap, target)
    let rendered = exists && widget_rendered(snap, target)
    let want_str = write_json(JV(expected))
    panic("expect_value({target}.{field}) gave up after {max_frames} frames:\n  want: {want_str}\n  got:  {got_str}\n  widget kind: {kind}\n  widget rendered: {rendered}")
}

def public expect_render(app : ImguiApp;
                         widget_ident : string;
                         timeout_sec : float = DEFAULT_FRAME_WAIT_SEC) : void {
    //! Assertion form of ``wait_for_render``; panics on timeout with the list of currently-registered widget identifiers (so typos in ``widget_ident`` surface).
    if (wait_for_render(app, widget_ident, timeout_sec) != null) return
    var snap = snapshot(app)
    var keys_buf = "<none>"
    let g = snap?["globals"]
    if (g != null && g is _object) {
        let obj & = unsafe(g as _object)
        var key_list : array<string>
        for (k in keys(obj)) {
            key_list |> push(k)
        }
        keys_buf = "[" + join(key_list, ", ") + "]"
    }
    panic("expect_render({widget_ident}) timeout after {timeout_sec}s — widget never reported rendered:true.\nRegistered widgets: {keys_buf}")
}

def public await_quiescent(app : ImguiApp;
                           timeout_sec : float = 5.0f) : void {
    //! Assertion wrapper over ``await_imgui(transport, "quiescent", timeout)``; panics on timeout.
    //! For a non-asserting poll, call ``await_imgui`` directly.
    if (await_imgui(app.transport, "quiescent", timeout_sec)) return
    panic("await_quiescent timeout after {timeout_sec}s — server never reported quiescent")
}

// ===== Command verbs =====

def public click(app : ImguiApp; target : string) : JsonValue? {
    //! Synthesize a click on ``target`` (``imgui_click`` verb).
    return send_imgui_command(app.transport, "imgui_click", JV((target = target)))
}

def public set_value(app : ImguiApp; target : string; var value : JsonValue?) : JsonValue? {
    //! Set ``target``'s payload value remotely (``imgui_set`` verb); ``value`` is the JSON form expected by the widget kind.
    return send_imgui_command(app.transport, "imgui_set", JV((target = target, value = value)))
}

def public open_widget(app : ImguiApp; target : string) : JsonValue? {
    //! Flip ``target.state.open = true`` (``imgui_open`` verb) — reopens a window/tree node from the test driver.
    return send_imgui_command(app.transport, "imgui_open", JV((target = target)))
}

def public close_widget(app : ImguiApp; target : string) : JsonValue? {
    //! Flip ``target.state.open = false`` (``imgui_close`` verb) — closes a window/tree node from the test driver.
    return send_imgui_command(app.transport, "imgui_close", JV((target = target)))
}

def public drag(app : ImguiApp; target : string;
                dx : float; dy : float;
                steps : int = 4; button : int = 0) : JsonValue? {
    //! Synthesize an L1 mouse-drag on ``target``'s bbox center: press → ``steps`` interpolated moves → release. Settles in ``steps + 2`` frames.
    return send_imgui_command(app.transport, "imgui_drag",
                              JV((target = target, dx = dx, dy = dy, steps = steps, button = button)))
}

def public drag_to(app : ImguiApp; source : string; target : string;
                   steps : int = 6; button : int = 0) : JsonValue? {
    //! Drag from ``source`` widget center to ``target`` widget center. Reads
    //! both bboxes from a fresh snapshot, computes the delta, and dispatches
    //! the L1 drag coroutine (press at source → interpolated moves → release).
    var snap = snapshot(app)
    let sb = snap?["globals"]?[source]?["bbox"]
    let tb = snap?["globals"]?[target]?["bbox"]
    let sx = ((sb?["x"] ?? 0.0f) + (sb?["z"] ?? 0.0f)) * 0.5f
    let sy = ((sb?["y"] ?? 0.0f) + (sb?["w"] ?? 0.0f)) * 0.5f
    let tx = ((tb?["x"] ?? 0.0f) + (tb?["z"] ?? 0.0f)) * 0.5f
    let ty = ((tb?["y"] ?? 0.0f) + (tb?["w"] ?? 0.0f)) * 0.5f
    return drag(app, source, tx - sx, ty - sy, steps, button)
}

def public focus(app : ImguiApp; target : string) : JsonValue? {
    //! Force keyboard focus to the next render of ``target`` (``imgui_focus`` verb); display-only widgets reply ``Result.err("not focusable")``.
    return send_imgui_command(app.transport, "imgui_focus", JV((target = target)))
}

def public wait_for_key_idle(app : ImguiApp; timeout_sec : float = DEFAULT_FRAME_WAIT_SEC) : bool {
    //! Poll ``imgui_key_status`` until ``playing == false`` or timeout; returns true on idle.
    //! Uses one HTTP request per poll (unlike a ``wait_until`` body that pairs a snapshot
    //! with a status call), keeping the per-subprocess connection count low on Windows.
    let start = ref_time_ticks()
    let timeout_usec = int(timeout_sec * 1000000.0f)
    while (get_time_usec(start) < timeout_usec) {
        let r = post_command(app, "imgui_key_status", null)
        if (!(r?["playing"] ?? true)) return true
        sleep(FRAME_POLL_INTERVAL_MS)
    }
    return false
}

def public wait_for_mouse_idle(app : ImguiApp; timeout_sec : float = DEFAULT_FRAME_WAIT_SEC) : bool {
    //! Poll ``imgui_mouse_status`` until ``playing == false`` or timeout; returns true on idle.
    //! Uses one HTTP request per poll (unlike a ``wait_until`` body that pairs a snapshot
    //! with a status call), keeping the per-subprocess connection count low on Windows.
    let start = ref_time_ticks()
    let timeout_usec = int(timeout_sec * 1000000.0f)
    while (get_time_usec(start) < timeout_usec) {
        let r = post_command(app, "imgui_mouse_status", null)
        if (!(r?["playing"] ?? true)) return true
        sleep(FRAME_POLL_INTERVAL_MS)
    }
    return false
}

def public await_probe(app : ImguiApp; until : string = "quiescent") : JsonValue? {
    //! Single ``imgui_await`` POST; the ``AwaitResult`` lives under ``response.value``.
    //! For poll-until-quiescent use ``await_quiescent``.
    return send_imgui_command(app.transport, "imgui_await", JV((until = until)))
}

def public type_text(app : ImguiApp; target : string; text : string;
                     focus_max_frames : int = 120;
                     duration_s : float = 0.0f) : JsonValue? {
    //! Auto-focus ``target``, wait up to ``focus_max_frames`` for focus to settle, then synthesize UTF-8 chars via L1 ``AddInputCharactersUTF8``.
    //! ``duration_s > 0`` paces typing over wall-clock (server: ``total_frames = int(duration_s * 60)``); default 0 keeps the 1-char/frame rate.
    focus(app, target)
    wait_until(app, focus_max_frames) $(var snap) {
        return snap?["globals"]?[target]?["focus"] ?? false
    }
    let total_frames = duration_s > 0.0f ? int(duration_s * 60.0f) : 0
    return send_imgui_command(app.transport, "imgui_type_text",
        JV((target = target, text = text, total_frames = total_frames)))
}

def public pause(app : ImguiApp) : void {
    //! POST ``/pause`` to halt the host's update() (skips advance_coroutines + render).
    //! POST /command continues to dispatch and POSTs still get drained by ``server.tick()``
    //! (which runs from the debug agent's onTick, gated by auto_tick_agents — not by paused).
    //! Useful for deterministic observation: spawn an L1 coroutine, probe ``imgui_await``
    //! while the world is frozen, then ``unpause`` to let it run.
    post_signal(app, "/pause")
}

def public unpause(app : ImguiApp) : void {
    //! POST ``/unpause`` to resume the host's update().
    post_signal(app, "/unpause")
}

def public with_paused(app : ImguiApp; body : block<() : void>) {
    //! Scope: ``pause`` the host, invoke ``body``, ``unpause``. Body observes a frozen
    //! world — coroutines spawned by ``imgui_drag`` / ``imgui_type_text`` sit unadvanced
    //! until unpause, so ``imgui_await`` reports ``pending_coroutines >= 1`` deterministically
    //! even in headless mode where the per-frame advance otherwise races the next HTTP POST.
    pause(app)
    body |> invoke()
    unpause(app)
}

def public reload(app : ImguiApp; timeout_sec : float = DEFAULT_RELOAD_TIMEOUT_SEC) : void {
    //! POST ``/reload`` then poll ``/status`` until ``has_error == false``; panics on timeout.
    //! Stays on raw HTTP — reload is daslang-live process control, not a dasImgui command verb.
    post_signal(app, "/reload")
    let start = ref_time_ticks()
    let timeout_usec = int(timeout_sec * 1000000.0f)
    while (get_time_usec(start) < timeout_usec) {
        let raw = get_text(app, "/status")
        if (!empty(raw)) {
            var err : string
            let parsed = read_json(raw, err)
            if (parsed != null) {
                let has_err = parsed?["has_error"] ?? false
                if (!has_err) return
            }
        }
        sleep(READY_POLL_INTERVAL_MS)
    }
    panic("reload did not converge on a clean compile within {timeout_sec}s")
}

def public with_imgui_app(feature_path : string; body : block<(app : ImguiApp) : void>) {
    //! Convenience form using the module-level default port + timeouts.
    //! For non-default knobs, use `with_imgui_app_opt`.
    with_imgui_app_opt(feature_path,
                       DEFAULT_LIVE_PORT,
                       DEFAULT_READY_TIMEOUT_SEC,
                       DEFAULT_TEST_TIMEOUT_SEC,
                       body)
}

var private g_headless_parsed : bool = false
var private g_headless_cached : bool = false

def private playwright_wants_headless() : bool {
    //! ``--headless`` forwarded from the dastest (or daslang.exe) invocation.
    //! Lazily parsed once; subsequent calls hit the cache. CI passes
    //! ``--headless`` on the dastest command line, every spawned daslang-live
    //! inherits it via ``-- --headless`` in argv. Local interactive runs
    //! omit the flag and stay windowed.
    if (g_headless_parsed) return g_headless_cached
    g_headless_parsed = true
    let args <- get_user_args()
    let raw = find_bool_flag_raw_value(args, "--headless")
    g_headless_cached = (raw |> unwrap_or("false")) == "true"
    return g_headless_cached
}

def public with_imgui_app_opt(feature_path : string;
                              port : int;
                              ready_timeout_sec : float;
                              test_timeout_sec : float;
                              body : block<(app : ImguiApp) : void>) {
    //! Spawn ``daslang-live <feature_path>``; runs ``body`` while alive, then POSTs ``/shutdown`` and drains stdout.
    //! Panics on non-zero exit code, ready-timeout, or test-timeout so the surrounding ``[test]`` fails.
    //! Forwards ``--headless`` (read from this process's ``get_user_args()``)
    //! into the spawn so the harness's headless arm fires inside the subprocess.
    let exe = daslang_live_exe()
    let app_path = resolve_feature_path(feature_path)
    var argv <- [exe, app_path]
    if (playwright_wants_headless()) {
        argv |> push("--")
        argv |> push("--headless")
        // Cascade guard: harness self-exits a few seconds before the popen
        // watchdog gives up. If body panics and /shutdown is never sent
        // (e.g. expect_value timeout — daslang's `finally` is skipped on
        // panic), the subprocess still releases port 9090 before the next
        // test spawns, instead of zombifying.
        let harness_budget = test_timeout_sec - 5.0f
        if (harness_budget > 5.0f) {
            argv |> push("--headless-timeout-sec={harness_budget}")
        }
    }
    let base_url = "http://127.0.0.1:{port}"
    var app = ImguiApp(base_url = base_url,
                       feature_path = app_path,
                       transport <- live_api_transport(base_url))
    var captured : string
    var unready = false
    print("[imgui_playwright] spawn argv: {argv}\n")
    let exit_code = unsafe(popen_argv(argv, test_timeout_sec, $(f) {
        if (f == null) {
            print("[imgui_playwright] popen returned null FILE\n")
            return
        }
        print("[imgui_playwright] subprocess up, polling /status...\n")
        if (!wait_until_ready(app, ready_timeout_sec)) {
            print("[imgui_playwright] readiness gate FAILED\n")
            unready = true
            captured = unsafe(fread_to_eof(f))
            return
        }
        print("[imgui_playwright] ready, invoking body\n")
        invoke(body, app)
        print("[imgui_playwright] body done, sending /shutdown\n")
        post_signal(app, "/shutdown")
        print("[imgui_playwright] /shutdown posted, draining pipe...\n")
        captured = unsafe(fread_to_eof(f))
        print("[imgui_playwright] drain done\n")
    }))
    print("[imgui_playwright] popen exit_code={exit_code}\n")
    if (unready) {
        panic("daslang-live not ready after {ready_timeout_sec}s.\nstdout/stderr:\n{captured}")
    }
    if (exit_code == popen_timed_out) {
        panic("daslang-live timed out (>{test_timeout_sec}s).\nstdout/stderr:\n{captured}")
    }
    if (exit_code != 0) {
        panic("daslang-live exited non-zero ({exit_code}).\nstdout/stderr:\n{captured}")
    }
}
