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
require daslib/module_path
require daslib/strings_boost
require strings
require math

// Module overview lives in handmade/module-imgui_playwright.rst.

// ===== Tunables =====

let DEFAULT_LIVE_PORT : int = 9090                   // daslang-live's live_api default port
let DEFAULT_DEADLOCK_SANITY_SEC : float = 120.0f     // backstop for the frame-counter-never-advances case (crash / true deadlock); never trips on slow-but-progressing
let DEFAULT_READY_TIMEOUT_SEC : float = 30.0f        // /status must turn 200 OK within this — covers daslang-live boot + GLFW + ImGui ctx
let ATTACH_PROBE_SEC : float = 0.3f                  // with_recording_app's attach-vs-spawn detection — short enough to feel instant when nothing's listening
let DEFAULT_TEST_TIMEOUT_SEC : float = 120.0f        // upper bound on the entire popen lifetime, including body + drain
let DEFAULT_RELOAD_TIMEOUT_SEC : float = 30.0f       // POST /reload to /status.has_error == false convergence
let DEFAULT_FRAME_WAIT_SEC : float = 10.0f           // upper bound on "first frame to render the named widget"

let READY_POLL_INTERVAL_MS : uint = 100u             // ms between /status polls — wait_until_ready and reload convergence
let FRAME_POLL_INTERVAL_MS : uint = 100u             // ms between snapshot polls — 10 req/sec; under libhv's Windows
                                                     // event-loop cap (~16 req/sec) that previously stalled the test
                                                     // sweep on heavy imgui_demo harnesses (see tests.yml comment).
                                                     // ~1.5 polls/frame at 60fps — still snappy in practice; most
                                                     // wait_for_widget calls complete in 1-2 polls anyway.

// ===== Centralized recording timing =====
//
// One knob set for every record_*.das. Drivers used to redeclare these as
// per-file lets (NARRATE_FRAMES / READ_MS / SETTLE_MS / CLICK_DWELL_MS) with
// inconsistent values across the corpus. RECORD_FPS is the nominal capture +
// playback grid: the synchronous APNG writer (daScript-side) never drops, and
// convert_recording reclocks the mp4 to the measured effective rate, so 30 keeps
// assets light without risking timeline drift.
//
// NARRATE_FRAMES is gone — the unified `narrate()` helper derives it from
// RECORD_FPS * NARRATE_READ_MS / 1000 so only one knob remains.

let public RECORD_FPS : int = 30                     // capture + playback grid; synchronous writer never drops, so APNG frame N == N/30s
let public NARRATE_READ_MS : uint = 4500u            // narrative on-screen window — long enough to read with audio muted
let public SETTLE_MS : uint = 1200u                  // post-move cursor settle
let public CLICK_DWELL_MS : uint = 1500u             // post-click visual confirmation

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
    //! Post a lerped cursor move from the last tracked position to ``pos``, with a brief dwell pin
    //! afterwards. Updates the tracked position. ``duration_ms`` is a FLOOR: the actual duration
    //! scales with distance (≈0.325 px/ms ≈ constant cursor speed) so a long move doesn't cover its
    //! span in the same time as a short one and read as a teleport; short moves keep the floor.
    let dist = max(abs(pos._0 - last_cursor_x), abs(pos._1 - last_cursor_y))
    let dur = max(duration_ms, int(dist / 0.325f))
    var events <- [
        JV((t_ms = 0,           kind = "move", x = last_cursor_x, y = last_cursor_y)),
        JV((t_ms = dur,         kind = "move", x = pos._0,        y = pos._1)),
        JV((t_ms = dur + 300,   kind = "move", x = pos._0,        y = pos._1))
    ]
    post_command(app, "imgui_mouse_play", JV((events = events)))
    unsafe { delete events; }
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

def public dasimgui_module_root() : string {
    //! dasImgui's module root resolved via `daslib/module_path`'s 3-tier walk.
    //! `get_this_module_dir()` returns the directory hosting this `.das` source
    //! (i.e. `<root>/widgets/`); one `dir_name` up gives the module root.
    //! Works in both layouts: CI's `<das_root>/modules/dasImgui/...` and the
    //! local-fix layout `D:/DASPKG/dasImgui/...` with no `modules/dasImgui`
    //! junction in `<das_root>`.
    return dir_name(get_this_module_dir())
}

def private resolve_feature_path(path : string; feature_root : string; feature_prefix : string) : string {
    if (is_absolute(path)) return path
    // Caller-supplied root/prefix first — lets another package (e.g. dasImguiNodeEditor)
    // resolve its own feature files under its own module root via `with_imgui_app`.
    if (feature_prefix != "" && path |> starts_with(feature_prefix)) return path_join(feature_root, slice(path, length(feature_prefix)))
    // Then dasImgui's own layout: strip `modules/dasImgui/` and resolve under the
    // runtime module root so tests find feature files regardless of layout.
    let prefix = "modules/dasImgui/"
    if (path |> starts_with(prefix)) return path_join(dasimgui_module_root(), slice(path, length(prefix)))
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
    POST("{app.base_url}{uri}", "", {"Content-Type" => "application/json"}) $(_resp) {
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

def public widget_click_point(var snap : JsonValue?; ident : string) : tuple<float; float> {
    //! The point ``imgui_click`` aims at for ``ident``: the left glyph (square check / radio
    //! circle) for the toggle family — checkbox / radio_button / radio_button_int — and the bbox
    //! center otherwise. Mirrors ``resolve_target_bbox`` in imgui_boost_runtime so a recording's
    //! ``move_to`` lands exactly where the click fires (no mid-row → glyph hop). Keep the kind list
    //! in sync with that resolver.
    var g = find_widget(snap, ident)
    let x0 = g?["bbox"]?["x"] ?? 0.0f
    let y0 = g?["bbox"]?["y"] ?? 0.0f
    let x1 = g?["bbox"]?["z"] ?? 0.0f
    let y1 = g?["bbox"]?["w"] ?? 0.0f
    let cy = (y0 + y1) * 0.5f
    let kind = g?["kind"] ?? ""
    if (kind == "checkbox" || kind == "radio_button" || kind == "radio_button_int") return (x0 + (y1 - y0) * 0.5f, cy)
    return ((x0 + x1) * 0.5f, cy)
}

def public widget_rendered(var snap : JsonValue?; ident : string) : bool {
    //! True iff ``globals[ident]`` EXISTS and painted this frame. Registered-but-unpainted entries
    //! carry ``"rendered": false``; painted widgets omit the field (``?? true``). The leading
    //! existence check is load-bearing: an absent (or misspelled) path yields ``null ?? true`` — a
    //! false pass — so a never-registered ident must report not-rendered, not silently "rendered".
    return widget_exists(snap, ident) && (snap?["globals"]?[ident]?["rendered"] ?? true)
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

def public wait_for_visible(app : ImguiApp; widget_ident : string;
                            timeout_sec : float = DEFAULT_FRAME_WAIT_SEC) : JsonValue? {
    //! Poll snapshot until ``widget_ident`` is registered AND painted this frame (``widget_rendered``).
    //! The robust gate for a widget that can hide and re-show: ``wait_for_widget`` returns on a stale
    //! registry entry left from a prior appearance (e.g. a re-opened popup / menu) while the widget
    //! is currently off-screen, so a click fired right after can dispatch before the widget
    //! re-renders and be silently dropped (no bbox this frame). Use this whenever the click target
    //! may have been shown before.
    let start = ref_time_ticks()
    let timeout_usec = int(timeout_sec * 1000000.0f)
    while (get_time_usec(start) < timeout_usec) {
        var snap = snapshot(app)
        if (snap != null && widget_rendered(snap, widget_ident)) return snap
        sleep(FRAME_POLL_INTERVAL_MS)
    }
    return null
}

def public wait_for_render(app : ImguiApp; widget_ident : string;
                           timeout_sec : float = DEFAULT_FRAME_WAIT_SEC) : JsonValue? {
    //! First-paint gate — alias of :func:`wait_for_visible`. ``widget_rendered`` now requires
    //! existence, so this no longer false-passes for an absent path. Prefer ``wait_for_visible``
    //! at call sites that target a widget which can hide and re-show.
    return wait_for_visible(app, widget_ident, timeout_sec)
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
    panic(format_value_mismatch(app, target, field, expected, max_frames))
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
        let key_list <- [for (k in keys(obj)); k]
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
    //! Synthesize a left-click on ``target`` (``imgui_click`` verb).
    return send_imgui_command(app.transport, "imgui_click", JV((target = target)))
}

def public right_click(app : ImguiApp; target : string) : JsonValue? {
    //! Synthesize a right-click on ``target`` (``imgui_click`` verb with ``button = 1``).
    //! Used by popup_context_item / popup_context_window drivers.
    return send_imgui_command(app.transport, "imgui_click", JV((target = target, button = 1)))
}

def public force_set_value(app : ImguiApp; target : string; var value : JsonValue?) : JsonValue? {
    //! Set ``target``'s payload value remotely (``imgui_force_set`` verb); ``value`` is the JSON form expected by the widget kind.
    return send_imgui_command(app.transport, "imgui_force_set", JV((target = target, value = value)))
}

def public force_set_verified(app : ImguiApp; target : string; value : auto(T); max_frames : int = 120) {
    //! Recording-as-test ``force_set``: set ``target.value`` to the typed ``value`` and verify it
    //! took. Accumulates a self-verification miss (surfaced as a loud panic at ``with_recording_app``
    //! teardown) rather than panicking mid-body — so the recording still stops + shuts the host
    //! down cleanly. For force_set-driven tutorial stages (slider / drag / input / color); the
    //! verified counterpart of the clicks ``hold_through_voice`` checks automatically. Use only
    //! inside a ``with_recording_app`` body — raw tests want the panicking ``expect_value``.
    force_set_value(app, target, JV(value))
    record_check_value(app, target, "value", value, max_frames)
}

def public resize_window(app : ImguiApp; target : string; w : float; h : float) : JsonValue? {
    //! Resize the window named by ``target`` to (``w``, ``h``) on the next frame.
    //! Routes through ``imgui_set_window_size`` (regular ``window`` container);
    //! the dispatcher feeds ``state.pending_size`` and ``window()`` calls
    //! ``SetNextWindowSize`` on the next frame. SetNextWindowSizeConstraints
    //! callbacks (snap/aspect/quantize) reshape the request — used by the
    //! window_size_constraints recording driver to demonstrate exactly that.
    //! Named ``resize_window`` (not ``set_window_size``) to avoid the
    //! overload-resolution collision with imgui_containers_builtin's
    //! in-frame ``set_window_size(size : float2; cond : ImGuiCond)``.
    return send_imgui_command(app.transport, "imgui_set_window_size",
                              JV((target = target, value = JV((w = w, h = h)))))
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
    //! Synthesize a mouse-drag on ``target``'s bbox center: warp → press → drag to
    //! ``center+(dx,dy)`` → release, composed as an ``imgui_mouse_play`` timeline. Resolves
    //! the bbox client-side from a fresh snapshot. Returns ``{ok, value=target}`` (``ok=false``
    //! when the target isn't in the snapshot, isn't rendered this frame, or the command post
    //! fails — a stale/unrendered widget would otherwise drag from a defaulted (0,0) bbox).
    //! ``steps`` scales the drag duration.
    var snap = snapshot(app)
    if (!(snap |> widget_exists(target))) return JV((ok = false, error = "drag target unresolved: {target}"))
    if (!(snap |> widget_rendered(target))) return JV((ok = false, error = "drag target not rendered this frame: {target}"))
    let bb = snap?["globals"]?[target]?["bbox"]
    let cx = ((bb?["x"] ?? 0.0f) + (bb?["z"] ?? 0.0f)) * 0.5f
    let cy = ((bb?["y"] ?? 0.0f) + (bb?["w"] ?? 0.0f)) * 0.5f
    let ex = cx + dx
    let ey = cy + dy
    let drag_ms = (steps > 0 ? steps : 1) * 32
    var events <- [
        JV((t_ms = 0,             kind = "move",   x = cx, y = cy)),
        JV((t_ms = 80,            kind = "button", button = button, action = "press")),
        JV((t_ms = 80 + drag_ms,  kind = "move",   x = ex, y = ey)),
        JV((t_ms = 180 + drag_ms, kind = "button", button = button, action = "release")),
        JV((t_ms = 280 + drag_ms, kind = "move",   x = ex, y = ey))
    ]
    let resp = post_command(app, "imgui_mouse_play", JV((events = events)))
    unsafe { delete events; }
    if (resp == null) return JV((ok = false, error = "drag post failed: {target}"))
    return JV((ok = true, value = target))
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

def public key_tap(app : ImguiApp; key : int) {
    //! Synthesize a complete press+release of an ImGuiKey by integer code.
    //! Pairs ``imgui_key_press`` + ``imgui_key_release`` — neither verb alone
    //! does both, so calling only press leaves the key stuck (visible in the
    //! key_hud overlay and as repeating-input bugs in driven widgets).
    //! Use ``int(ImGuiKey.Tab)`` / ``int(ImGuiKey.Escape)`` / etc. at the call site.
    post_command(app, "imgui_key_press",   JV((key = key)))
    post_command(app, "imgui_key_release", JV((key = key)))
}

// ===== Voiceover sync (record-time, opt-in via a prepared manifest) =====
// prepare_recording.das pre-renders each say() line to a wav and writes
// voiceover/<stem>.manifest.json beside the APNG. with_recording_app auto-arms when that
// manifest exists; say() then paces each line by its wav duration and records the wall-clock
// offset where the caption (hence the voice) begins. No manifest -> unchanged behavior.

struct public VoEntry {
    hash  : string      //!< say_hash(spoken) — links a narration line to its wav
    text  : string      //!< on-screen caption (the say() text arg)
    voice : string      //!< spoken line fed to TTS (say() voice arg, or text if none)
    wav   : string      //!< wav basename under the voiceover/ dir
    dur_s : float       //!< measured wav duration, seconds
}

struct public VoManifest {
    voice   : string
    gap_ms  : int = 500
    entries : array<VoEntry>
}

struct public VoSidecarHit {
    frame : int         //!< recorded APNG frame index at the caption's appearance — the sync anchor
    t_s   : float       //!< wall-clock seconds from record_start (reference/debug; convert uses frame)
    wav   : string      //!< wav basename to mux
    text  : string      //!< narration line (for reference)
}

struct public VoSidecar {
    apng       : string
    fps        : int
    frames     : int
    duration_s : float
    voiceovers : array<VoSidecarHit>
}

def public say_hash(text : string) : string {
    //! Stable wav key shared by prepare_recording.das and say(); hash() is deterministic.
    return "{hash(text)}"
}

var private g_vo_active = false
var private g_vo_gap_ms = 500u
var private g_vo_stem : string                  // apng stem, for reconstructing wav names
var private g_vo_dur : table<string; float>     // hash -> wav duration (seconds)
var private g_vo_collect : array<VoSidecarHit>  // accumulated while a voiceover recording runs
var private g_vo_extra_s = 0.0f                 // total added dwell (sum of wav_dur + gap) — extends the recorder cap
var private g_record_failures : array<string>   // self-verification misses during a recording; surfaced (panic) at with_recording_app teardown

def private format_value_mismatch(app : ImguiApp; target : string; field : string; expected : auto(T); max_frames : int) : string {
    //! The want/got/kind/rendered diagnostic shared by ``expect_value`` (panics with it) and the
    //! recording sequencer's ``record_check_value`` (accumulates it).
    var snap = snapshot(app)
    let got_jv = widget_payload_field(snap, target, field)
    let got_str = got_jv != null ? write_json(got_jv) : "<missing>"
    let kind = snap?["globals"]?[target]?["kind"] ?? "<unknown>"
    let exists = widget_exists(snap, target)
    let rendered = exists && widget_rendered(snap, target)
    let want_str = write_json(JV(expected))
    return "expect_value({target}.{field}) gave up after {max_frames} frames:\n  want: {want_str}\n  got:  {got_str}\n  widget kind: {kind}\n  widget rendered: {rendered}"
}

def public record_check_value(app : ImguiApp; target : string; field : string; expected : auto(T); max_frames : int = 120) : bool {
    //! Recording-safe verifier: assert ``target.payload[field] == expected`` within ``max_frames``,
    //! accumulating a miss instead of panicking. This is the public rail for self-verifying a NON-CLICK
    //! effect in a recording — drive the real gesture (``move_to`` to hover, ``drag`` / ``drag_to``,
    //! ``type_text``) then call this to assert the effect landed (the hover status updated, the slider
    //! value moved, the field took the text). Clicks already verify through ``hold_through_voice`` /
    //! ``verify_click_effect``, which call this internally; ``force_set_verified`` uses it too.
    //! A recording body must NOT panic mid-run: daslang panic is fatal and can't be recovered-and-continued,
    //! so a mid-body panic would skip the clean record_stop + /shutdown and orphan the host. So on a
    //! mismatch we push the same diagnostic ``expect_value`` would panic with onto ``g_record_failures``
    //! and return false; the body runs to its normal teardown, then ``with_recording_app`` fails loudly
    //! after the host is drained. Returns true when the value matched.
    if (wait_for_payload_value(app, target, field, expected, max_frames)) return true
    g_record_failures |> push(format_value_mismatch(app, target, field, expected, max_frames))
    return false
}

def private arm_voiceovers(apng_path : string) : bool {
    //! Load voiceover/<stem>.manifest.json beside apng_path. On success fill g_vo_dur, set
    //! g_vo_active, clear the collection. Returns true when armed.
    g_vo_active = false
    g_vo_stem = stem(apng_path)
    g_vo_dur |> clear()
    g_vo_collect |> clear()
    let manifest_path = path_join(path_join(dir_name(apng_path), "voiceover"), "{g_vo_stem}.manifest.json")
    let txt = fread(manifest_path)
    if (empty(txt)) return false
    var err : string
    let jv = read_json(txt, err)
    if (jv == null) {
        print("[voiceover] bad manifest {manifest_path}: {err}\n")
        return false
    }
    let m = from_JV(jv, type<VoManifest>)
    g_vo_gap_ms = uint(m.gap_ms > 0 ? m.gap_ms : 500)
    g_vo_extra_s = 0.0f
    let gap_s = float(g_vo_gap_ms) / 1000.0f
    for (e in m.entries) {
        g_vo_dur[e.hash] = e.dur_s
        g_vo_extra_s += e.dur_s + gap_s
    }
    g_vo_active = !empty(g_vo_dur)
    if (g_vo_active) {
        print("[voiceover] armed: {length(m.entries)} lines, gap {int(g_vo_gap_ms)}ms, voice {m.voice}\n")
    }
    return g_vo_active
}

def private flush_voiceovers(stopped : JsonValue?; apng_path : string; fps : int) {
    //! After record_stop, write voiceover/<stem>.sidecar.json (clip length + per-line offsets).
    if (!g_vo_active) return
    g_vo_active = false
    let sidecar_path = path_join(path_join(dir_name(apng_path), "voiceover"), "{stem(apng_path)}.sidecar.json")
    let sc = VoSidecar(apng = base_name(apng_path), fps = fps,
        frames = stopped?["frames"] ?? 0,
        duration_s = stopped?["duration_s"] ?? 0.0f,
        voiceovers <- g_vo_collect)
    if (!fwrite(sidecar_path, write_json(JV(sc)))) {
        print("[voiceover] FAILED to write {sidecar_path}\n")
        return
    }
    print("[voiceover] wrote {sidecar_path} ({length(sc.voiceovers)} lines, {sc.duration_s}s)\n")
}

// ===== Recording cadence helper =====

def private say_begin_impl(app : ImguiApp; text : string; targets : array<string>;
                           read_ms : uint; voice : string) : uint {
    // Shared body for both say_begin forms — posts imgui_narrate with the targets list (first is
    // the anchor, all hard-avoided) and returns the dwell WITHOUT sleeping. In voiceover mode the
    // dwell is the wav length (+gap), held by wall-clock duration_s (render fps diverges from the
    // capture grid, so a tick budget would drain early and the box would vanish mid-voiceover);
    // otherwise read_ms.
    let spoken = voice != "" ? voice : text
    if (g_vo_active) {
        let h = say_hash(spoken)
        if (key_exists(g_vo_dur, h)) {
            let dwell_s = g_vo_dur[h] + float(g_vo_gap_ms) / 1000.0f
            post_command(app, "imgui_narrate", JV((text = text, targets = JV(targets), duration_s = dwell_s)))
            let st = post_command(app, "record_status", null)
            g_vo_collect |> push(VoSidecarHit(frame = st?["frames"] ?? 0,
                t_s = st?["elapsed_s"] ?? 0.0f,
                wav = "{g_vo_stem}_{h}.wav", text = text))
            return uint(dwell_s * 1000.0f)
        }
    }
    post_command(app, "imgui_narrate", JV((text = text, targets = JV(targets),
        duration_s = float(read_ms) / 1000.0f)))
    return read_ms
}

def public say_begin(app : ImguiApp; text : string; target : string = ""; read_ms : uint = NARRATE_READ_MS; voice : string = "") : uint {
    //! Non-blocking ``say``: post the narration overlay (+ record the voiceover anchor) and
    //! RETURN the dwell in milliseconds WITHOUT sleeping. The caller then sleeps the returned
    //! dwell — splitting it around a ``click`` / ``drag`` so the action lands visibly under the
    //! voice (cursor lands -> say_begin -> short lead -> click -> hold the remainder). For plain
    //! narration with no mid-dwell action, use ``say`` which posts + sleeps in one call.
    //! ``text`` is the on-screen caption; ``voice`` (when set) is the spoken line — write
    //! captions for the eye (terse) and voice for the ear (natural sentences). Empty voice
    //! falls back to text. For a step spanning sibling controls, use the ``targets`` overload.
    return say_begin_impl(app, text, [target], read_ms, voice)
}

def public say_begin(app : ImguiApp; text : string; targets : array<string>; read_ms : uint = NARRATE_READ_MS; voice : string = "") : uint {
    //! Multi-target ``say_begin``: the caption points at ``targets[0]`` and is placed to HARD-avoid
    //! the union of all ``targets``' bboxes — pass the same list ``hold_through_voice`` will click so
    //! the box never covers a sibling control (e.g. an arrow_button pair). Otherwise identical to the
    //! single-target form (returns the dwell; the caller sleeps it).
    return say_begin_impl(app, text, targets, read_ms, voice)
}

def public say(app : ImguiApp; text : string; target : string = ""; read_ms : uint = NARRATE_READ_MS; voice : string = "") {
    //! Pop a narration overlay (``imgui_narrate`` verb), then sleep for the dwell so the
    //! recorder captures the on-screen window. The overlay is held by wall-clock ``duration_s``
    //! (the same span as the sleep), not a tick budget, so it lingers correctly even though
    //! render fps and capture fps diverge during recording. In voiceover mode the dwell is the
    //! wav length (+gap) instead, so the caption stays up exactly while the voice speaks.
    //! Named ``say`` (not ``narrate``) to avoid overload-resolution churn with
    //! imgui_visual_aids::narrate (the host-side overlay function), which differs
    //! only in the first arg type (string vs ImguiApp). For a click/drag that must land under
    //! the voice, use ``say_begin`` + a manual dwell split instead.
    sleep(say_begin(app, text, target, read_ms, voice))
}

def public say(app : ImguiApp; text : string; targets : array<string>; read_ms : uint = NARRATE_READ_MS; voice : string = "") {
    //! Multi-target ``say``: caption points at ``targets[0]`` and HARD-avoids the union of all
    //! ``targets`` (see the ``say_begin`` list overload), then sleeps the dwell.
    sleep(say_begin(app, text, targets, read_ms, voice))
}

def private is_button_kind(kind : string) : bool {
    return (kind == "button" || kind == "small_button" || kind == "arrow_button" ||
            kind == "invisible_button" || kind == "image_button" || kind == "tab_item_button")
}

def private split_alias(target : string) : tuple<string; int> {
    //! "X#v" -> (ground "X", v_button v); plain "X" -> ("X", 0). The per-site radio alias suffix.
    let h = find(target, "#")
    if (h < 0) return (target, 0)
    return (slice(target, 0, h), to_int(slice(target, h + 1)))
}

def private verify_click_effect(app : ImguiApp; target : string; var pre : JsonValue?) {
    //! Verify the kind-appropriate effect of clicking ``target`` actually happened — a recording is
    //! also a test, so a no-op click (landed off, or nothing changed) is recorded as a failure (via
    //! ``record_check_value``, surfaced at teardown). Effect-by-kind doubles as a landing check: if
    //! the click missed, the state wouldn't move. Kinds with no click-tracked field (sliders etc. —
    //! recordings don't click them) skip.
    let (ground, vb) = split_alias(target)
    let kind = find_widget(pre, ground)?["kind"] ?? ""
    if (empty(kind)) return
    if (is_button_kind(kind)) {
        let pre_cc = widget_payload_field(pre, ground, "click_count") ?? 0
        record_check_value(app, ground, "click_count", pre_cc + 1, 120)
    } elif (kind == "radio_button_int") {
        record_check_value(app, ground, "value", vb, 120)
    } elif (kind == "checkbox" || kind == "radio_button" || kind == "selectable" || kind == "menu_item") {
        let pre_v = widget_payload_field(pre, ground, "value") ?? false
        record_check_value(app, ground, "value", !pre_v, 120)
    }
}

def public hold_through_voice(app : ImguiApp; dwell : uint; clicks : array<string>) {
    //! Pace the click(s) in ``clicks`` UNDER an already-posted voice line: a short lead lets the
    //! box + voice start, then each click lands (ripple + state change visible while the voice
    //! plays), then hold the caption for the rest of its voice. ``dwell`` is the value returned
    //! by ``say_begin``; pass the caption/voice LITERALS to ``say_begin`` at the call site (so
    //! prepare_recording can scan them) and forward its result here. The caller must have already
    //! moved the cursor onto the first target. Each click is VERIFIED (the effect must register,
    //! or the recording aborts) and the tracked cursor is advanced to the click's resolved point
    //! so the next move_to starts there (no teleport). Multi-click stages dwell a beat between
    //! picks so each state is visible.
    let lead = dwell > 1200u ? 500u : dwell / 3u
    sleep(lead)
    let n = length(clicks)
    let body_ms = dwell > lead ? dwell - lead : 0u
    let beat = n > 0 ? body_ms / uint(n) : body_ms
    for (target in clicks) {
        var pre = snapshot(app)
        click(app, target)                              // animated approach + press/release
        verify_click_effect(app, target, pre)           // panics if the click had no effect
        reset_cursor_pos(widget_click_point(pre, target))  // track where the click left the cursor
        sleep(beat)
    }
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
    //! Auto-focus ``target``, wait up to ``focus_max_frames`` for focus to settle, then stream
    //! ``text`` as synthetic key+char events via ``imgui_key_type`` (into whichever widget holds
    //! focus). Returns ``{ok, value=target}`` (``ok=false`` on empty text or if focus never settles). ``duration_s > 0``
    //! paces typing over wall-clock; default uses ``imgui_key_type``'s per-char cadence.
    if (empty(text)) return JV((ok = false, error = "missing text"))
    focus(app, target)
    let focused = wait_until(app, focus_max_frames) $(var snap) {
        return snap?["globals"]?[target]?["focus"] ?? false
    }
    if (focused == null) return JV((ok = false, error = "focus never settled: {target}"))
    var args = (duration_s > 0.0f) ? JV((text = text, total_duration_s = duration_s)) : JV((text = text))
    let resp = post_command(app, "imgui_key_type", args)
    unsafe { delete args; }
    if (resp == null) return JV((ok = false, error = "type post failed: {target}"))
    return JV((ok = true, value = target))
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
    //! world — coroutines spawned by ``imgui_click`` sit unadvanced until unpause, so
    //! ``imgui_await`` reports ``pending_coroutines >= 1`` deterministically even in
    //! headless mode where the per-frame advance otherwise races the next HTTP POST.
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

var private g_worker_index_parsed : bool = false
var private g_worker_index_cached : int = 0

def private playwright_worker_index() : int {
    //! ``--worker-index N`` forwarded from dastest's isolated-mode worker.
    //! Lazily parsed once. Used by ``with_imgui_app`` to derive a per-worker
    //! live-API port (DEFAULT_LIVE_PORT + worker_index), so N parallel
    //! dastest workers don't collide on the same TCP port. Defaults to 0
    //! when absent (sequential mode), giving the same port the codebase has
    //! always used.
    if (g_worker_index_parsed) return g_worker_index_cached
    g_worker_index_parsed = true
    let args <- get_user_args()
    let raw = find_flag_raw_value(args, "--worker-index") |> unwrap_or("0")
    g_worker_index_cached = to_int(raw)
    return g_worker_index_cached
}

def public with_imgui_app(feature_path : string;
                          body : block<(app : ImguiApp) : void>) {
    //! Spawn ``daslang-live <feature_path>`` with the dasImgui module loaded; runs
    //! ``body`` while alive, then POSTs ``/shutdown`` and drains stdout. Panics on
    //! non-zero exit code, ready-timeout, or test-timeout so the surrounding
    //! ``[test]`` fails. The common case — for a feature whose ``require`` chain
    //! needs ONLY dasImgui. Delegates to the 5-arg overload with no extra modules.
    let no_extra : array<string>
    with_imgui_app(feature_path, no_extra, "", "", body)
}

def public with_imgui_app(feature_path : string;
                          extra_module_roots : array<string>;
                          feature_root : string;
                          feature_prefix : string;
                          body : block<(app : ImguiApp) : void>) {
    //! Full form — spawn ``daslang-live`` for a feature whose ``require`` chain
    //! needs dasImgui PLUS the modules at ``extra_module_roots`` (each gets its own
    //! ``-load_module``, appended after dasImgui's so dependency order holds). A
    //! relative ``feature_path`` starting with ``feature_prefix`` resolves under
    //! ``feature_root`` (pass ``""``/``""`` to use dasImgui's default resolution).
    //! This is how another package (e.g. dasImguiNodeEditor) drives its own app
    //! without duplicating the spawn/port/headless/ready/shutdown machinery — the
    //! extra-module config is threaded through args, not module globals.
    //!
    //! Port is always DEFAULT_LIVE_PORT + worker_index — sequential runs (no
    //! --worker-index in argv) get 9090; dastest's isolated mode brands each
    //! worker's subprocess argv with --worker-index N so N parallel workers
    //! land on distinct ports (9090..9090+N-1) and don't collide.
    //!
    //! Forwards ``--headless`` (read from this process's ``get_user_args()``)
    //! into the spawn so the harness's headless arm fires inside the subprocess.
    let exe = daslang_live_exe()
    let port = DEFAULT_LIVE_PORT + playwright_worker_index()
    let ready_timeout_sec = DEFAULT_READY_TIMEOUT_SEC
    let test_timeout_sec = DEFAULT_TEST_TIMEOUT_SEC
    let app_path = resolve_feature_path(feature_path, feature_root, feature_prefix)
    // -load_module points the spawned daslang-live at the dasImgui module so
    // the feature's `require imgui/...` chain resolves regardless of layout.
    // In CI dasImgui is in the standard module search path so this is a
    // harmless duplicate; locally it's load-bearing. Extra roots follow, so a
    // dependent module (e.g. node-editor, which requires dasImgui) loads after it.
    //
    // --live-port pins the spawned daslang-live's HTTP API to the same port
    // playwright's base_url targets, so daslang-live's single-instance-lock
    // keys off the same port playwright dials.
    var argv <- [exe, "-load_module", dasimgui_module_root()]
    argv |> reserve(length(argv) + length(extra_module_roots) * 2)
    for (root in extra_module_roots) {
        argv |> push("-load_module")
        argv |> push(root)
    }
    argv |> push("--live-port={port}")
    argv |> push(app_path)
    if (playwright_wants_headless()) {
        argv |> push("--")
        argv |> push("--headless")
        // Cascade guard: harness self-exits a few seconds before the popen
        // watchdog gives up. If body panics and /shutdown is never sent
        // (e.g. expect_value timeout — daslang's `finally` is skipped on
        // panic), the subprocess still releases its port before the next
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
    let exit_code = unsafe(popen_argv(argv, test_timeout_sec, $(f) {
        return if (f == null)
        if (!wait_until_ready(app, ready_timeout_sec)) {
            unready = true
            captured = unsafe(fread_to_eof(f))
            return
        }
        invoke(body, app)
        post_signal(app, "/shutdown")
        captured = unsafe(fread_to_eof(f))
    }))
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

// ===== Recording helper =====

let public RECORD_ASSET_REL = "doc/source/_static/tutorials"
let private RECORD_FPS_DEFAULT = RECORD_FPS  // nominal capture+playback grid — see the tunables section above

def public with_recording_app(feature_path : string;
                              output_apng_basename : string;
                              max_seconds : int;
                              body : block<(app : ImguiApp) : void>) {
    //! Native-fps form (the common case). Delegates to the 4-arg overload —
    //! daslang's gen2 trailing-block sugar can't see through a default
    //! parameter sitting between the last positional and the block, so
    //! the overload pair keeps the common call site clean.
    with_recording_app(feature_path, output_apng_basename, max_seconds, RECORD_FPS_DEFAULT, body)
}

def public with_recording_app(feature_path : string;
                              output_apng_basename : string;
                              max_seconds : int;
                              fps : int;
                              body : block<(app : ImguiApp) : void>) {
    //! dasImgui-only form — feature + assets rooted under dasImgui, no extra
    //! modules. Delegates to the full form below; another package
    //! (dasImguiNodeEditor) calls the full form directly with its own roots.
    let no_extra : array<string>
    let root = dasimgui_module_root()
    with_recording_app(feature_path, output_apng_basename, max_seconds, fps,
                       no_extra, root, root, body)
}

def public with_recording_app(feature_path : string;
                              output_apng_basename : string;
                              max_seconds : int;
                              fps : int;
                              extra_module_roots : array<string>;
                              feature_root : string;
                              asset_root : string;
                              body : block<(app : ImguiApp) : void>) {
    //! Run a recording session against ``feature_path``. If a daslang-live
    //! host is already serving at the live-API port, **attach** to it (the
    //! running host's current HDPI/style — dev workflow: iterate live, then
    //! flip the recorder on without restarting). Otherwise **spawn** a new
    //! host at logical 1x (passes ``--imgui-content-scale=1.0`` +
    //! ``--no-hdpi-framebuffer`` after ``--`` so framebuffer + ImGui style
    //! both stay at logical resolution; APNGs stay encoder-friendly even on
    //! retina — canonical-recording workflow). Toggles visual aids, posts
    //! ``record_start``, runs ``body`` for the narrate/click/drag timeline,
    //! then ``record_stop``. Spawned host gets ``/shutdown`` + drain;
    //! attached host is left running.
    //!
    //! In attach mode the caller owns whatever feature is loaded — the
    //! helper does NOT post a switch-feature command. If the running host
    //! has a different feature loaded, the driver body's
    //! ``wait_for_render`` call will time out and the driver panics with
    //! the standard "{ident} never rendered — wrong app running?" message.
    //!
    //! Spawns ``daslang-live`` with ``-load_module`` for dasImgui plus each
    //! root in ``extra_module_roots`` (after dasImgui's, so dependency order
    //! holds) — this is how another package (dasImguiNodeEditor) records a
    //! feature whose ``require`` chain needs its module too. A relative
    //! ``feature_path`` resolves under ``feature_root``; the APNG lands under
    //! ``<asset_root>/doc/source/_static/tutorials/`` regardless of caller cwd.
    //! ``fps`` defaults to ``RECORD_FPS`` (the nominal capture+playback grid). Panics on
    //! non-zero exit / readiness or test timeout so the driver fails loudly.
    // Relative feature_path resolves under feature_root (the calling package's
    // module root, where examples/tutorial/ + examples/features/ live); the
    // APNG lands under asset_root. The 5-arg delegate defaults both to dasImgui.
    var app_path = feature_path
    if (!is_absolute(app_path)) {
        app_path = path_join(feature_root, app_path)
    }
    let asset_dir = path_join(asset_root, RECORD_ASSET_REL)
    let output_apng_path = path_join(asset_dir, output_apng_basename)
    arm_voiceovers(output_apng_path)
    g_record_failures |> clear()   // fresh self-verification ledger for this recording
    // Voiceover dwells make the body run far longer than the silent-record cap.
    // The cap is only a safety backstop (real length comes from record_stop), so
    // extend it by the total added narration time when armed.
    let eff_max_seconds = g_vo_active ? max_seconds + int(g_vo_extra_s) + 5 : max_seconds

    let base_url = "http://127.0.0.1:{DEFAULT_LIVE_PORT}"
    var app = ImguiApp(base_url = base_url,
                       feature_path = app_path,
                       transport <- live_api_transport(base_url))

    // Attach-mode probe: 0.3 s is enough for three /status polls (instant
    // on a healthy listener, fast TCP-refused if no one's there).
    if (wait_until_ready(app, ATTACH_PROBE_SEC)) {
        print("[record] attaching to existing daslang-live at {base_url}\n")
        post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
        post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
        // Windowed glfw re-polls the real OS cursor into io.MousePos every frame; detach real
        // input so synth fully owns IO, else synth clicks land wherever the real mouse sits.
        post_command(app, "set_user_control",     JV((enabled = false)))
        post_command(app, "record_start", JV((
            file = output_apng_path,
            fps = fps,
            max_seconds = eff_max_seconds
        )))
        invoke(body, app)
        let stopped = post_command(app, "record_stop", null)
        let dump = stopped != null ? write_json(stopped) : "<null>"
        print("[record] record_stop -> {dump}\n")
        print("[record] APNG saved to {output_apng_path}\n")
        flush_voiceovers(stopped, output_apng_path, fps)
        post_command(app, "set_user_control",     JV((enabled = true)))
        post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
        post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
        // Host stays running (we didn't spawn it). The body never panics on a failed interaction;
        // it accumulates misses, so the recording stops cleanly above — now fail loudly if any.
        if (!empty(g_record_failures)) {
            panic(record_failures_message())
        }
        return
    }

    let exe = daslang_live_exe()
    // -load_module dasImgui (+ each extra root after it, dependency order) so
    // the spawned host resolves the feature's `require imgui/...` chain
    // regardless of layout — same explicit-load model as with_imgui_app. In CI
    // dasImgui is on the module search path so its entry is a harmless
    // duplicate; locally it's load-bearing. Extra roots let a dependent package
    // (e.g. node-editor, which requires dasImgui) load after it.
    var argv <- [exe, "-load_module", dasimgui_module_root()]
    argv |> reserve(length(argv) + length(extra_module_roots) * 2)
    for (extra_root in extra_module_roots) {
        argv |> push("-load_module")
        argv |> push(extra_root)
    }
    argv |> push(app_path)
    argv |> push("--")
    argv |> push("--imgui-content-scale=1.0")
    // Ask glfw_live to skip the HDPI backing on retina / Windows DPI so the
    // framebuffer (and the APNG capture that reads it via glReadPixels) match
    // the requested logical size. Without this, captures stay at physical 2x
    // even when the style is 1x — UI is small inside a big frame.
    argv |> push("--no-hdpi-framebuffer")

    var captured : string
    var unready  = false
    // Body must complete within max_seconds + ready/shutdown headroom.
    let test_timeout_sec = float(eff_max_seconds) + 30.0f
    let exit_code = unsafe(popen_argv(argv, test_timeout_sec, $(f) {
        return if (f == null)
        if (!wait_until_ready(app, DEFAULT_READY_TIMEOUT_SEC)) {
            unready = true
            captured = unsafe(fread_to_eof(f))
            return
        }
        post_command(app, "imgui_mouse_trail",   JV((enabled = true)))
        post_command(app, "imgui_cursor_sprite", JV((enabled = true)))
        // Windowed glfw re-polls the real OS cursor into io.MousePos every frame; detach real
        // input so synth fully owns IO, else synth clicks land wherever the real mouse sits.
        post_command(app, "set_user_control",     JV((enabled = false)))
        post_command(app, "record_start", JV((
            file = output_apng_path,
            fps = fps,
            max_seconds = eff_max_seconds
        )))
        // The body never panics on a failed interaction — it accumulates misses into
        // g_record_failures (recovering-and-continuing from a daslang panic isn't supported, so we
        // can't catch mid-body and still shut down cleanly). So record_stop + /shutdown always run;
        // the misses are surfaced after popen drains, below.
        invoke(body, app)
        let stopped = post_command(app, "record_stop", null)
        let dump = stopped != null ? write_json(stopped) : "<null>"
        print("[record] record_stop -> {dump}\n")
        print("[record] APNG saved to {output_apng_path}\n")
        flush_voiceovers(stopped, output_apng_path, fps)
        post_command(app, "set_user_control",     JV((enabled = true)))
        post_command(app, "imgui_cursor_sprite", JV((enabled = false)))
        post_command(app, "imgui_mouse_trail",   JV((enabled = false)))
        post_signal(app, "/shutdown")
        captured = unsafe(fread_to_eof(f))
    }))
    if (unready) {
        panic("daslang-live not ready after {DEFAULT_READY_TIMEOUT_SEC}s.\nstdout/stderr:\n{captured}")
    }
    if (exit_code == popen_timed_out) {
        panic("daslang-live timed out (>{test_timeout_sec}s).\nstdout/stderr:\n{captured}")
    }
    if (exit_code != 0) {
        panic("daslang-live exited non-zero ({exit_code}).\nstdout/stderr:\n{captured}")
    }
    if (!empty(g_record_failures)) {
        // Host shut down cleanly above; surface the self-verification misses now (after drain) so
        // the recording fails loudly with every want/got diagnostic + the subprocess stdout/stderr.
        panic("{record_failures_message()}\nstdout/stderr:\n{captured}")
    }
}

def private record_failures_message() : string {
    //! Join the accumulated self-verification misses into one loud teardown message.
    return ("recording self-verification failed — {length(g_record_failures)} interaction(s) did not register:\n" +
            join(g_record_failures, "\n---\n"))
}
