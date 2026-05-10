options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module live_driver public

require dashv/dashv_boost public
require daslib/fio public
require daslib/json public
require daslib/json_boost public
require daslib/command_line
require daslib/strings_boost
require strings

//! Playwright-style test harness for daslang-live + dasImgui.
//!
//! `with_live_app(feature_path) <| $(d) { ... }` spawns daslang-live against
//! the given .das file, polls /status until ready, runs the body, POSTs
//! /shutdown, drains stdout, and panics on non-zero subprocess exit. The body
//! talks to the live_api over HTTP via `snapshot` / `click` / `set_value` /
//! `open_widget` / `close_widget` / `reload` / `post_command`.
//!
//! Each helper uses dashv's fire-and-forget HTTP client. Replies are parsed
//! as JSON; the helpers return `JsonValue?` so test files can navigate fields
//! via `?[...]` and `from_JV(...)`.

// ===== Tunables =====
//
// Sleep durations and timeouts. Pulled out of the call sites so a single
// place documents what each gate is waiting on, and so per-test overrides
// (slower CI box, longer-warmup demos) are a one-line change.

let DEFAULT_LIVE_PORT : int = 9090                   //! daslang-live's live_api default port
let DEFAULT_READY_TIMEOUT_SEC : float = 30.0f        //! /status must turn 200 OK within this — covers daslang-live boot + GLFW + ImGui ctx
let DEFAULT_TEST_TIMEOUT_SEC : float = 120.0f        //! upper bound on the entire popen lifetime, including body + drain
let DEFAULT_RELOAD_TIMEOUT_SEC : float = 30.0f       //! POST /reload to /status.has_error == false convergence
let DEFAULT_FRAME_WAIT_SEC : float = 10.0f           //! upper bound on "first frame to render the named widget"

let READY_POLL_INTERVAL_MS : uint = 100u             //! ms between /status polls — used by wait_until_ready and reload-convergence loops
let FRAME_POLL_INTERVAL_MS : uint = 50u              //! ms between snapshot polls — wait_for_widget polls per-frame, ~3 polls/frame at 60fps

struct LiveDriver {
    base_url : string
    feature_path : string
}

def private daslang_live_exe() : string {
    //! Resolve the daslang-live executable next to the running interpreter.
    //! Mirrors `get_das_exe()` (daslib/command_line) — same dir, swap the
    //! last path component for the platform-appropriate `daslang-live` name.
    let das = get_das_exe()
    if (empty(das)) {
        return ""
    }
    let dir = dir_name(das)
    let bin = get_platform_name() == "windows" ? "daslang-live.exe" : "daslang-live"
    return path_join(dir, bin)
}

def private resolve_feature_path(path : string) : string {
    if (is_absolute(path)) {
        return path
    }
    return path_join(get_das_root(), path)
}

def public wait_until_ready(d : LiveDriver; timeout_sec : float) : bool {
    //! Poll GET /status until 200 OK or timeout. Returns true on ready.
    let deadline = ref_time_ticks() + int64(timeout_sec * 1000000.0f)
    while (ref_time_ticks() < deadline) {
        var ok = false
        GET("{d.base_url}/status") $(resp) {
            if (resp != null && resp.status_code == http_status.OK) {
                ok = true
            }
        }
        if (ok) {
            return true
        }
        sleep(READY_POLL_INTERVAL_MS)
    }
    return false
}

def public post_json(d : LiveDriver; uri : string; body : string) : string {
    //! POST a JSON body to `uri`; return the raw response body or "" on transport failure.
    var out : string
    POST("{d.base_url}{uri}", body, {"Content-Type" => "application/json"}) $(resp) {
        if (resp != null) {
            out = string(resp.body)
        }
    }
    return out
}

def public get_text(d : LiveDriver; uri : string) : string {
    //! GET `uri`; return the raw response body or "".
    var out : string
    GET("{d.base_url}{uri}") $(resp) {
        if (resp != null) {
            out = string(resp.body)
        }
    }
    return out
}

def private post_signal(d : LiveDriver; uri : string) {
    //! Fire-and-forget POST with empty body. Used for /reload and /shutdown.
    POST("{d.base_url}{uri}", "", {"Content-Type" => "application/json"}) $(resp) {
        // intentionally drop the response — caller polled /status to confirm
    }
}

def public post_command(d : LiveDriver; name : string; var args : JsonValue?) : JsonValue? {
    //! POST /command with `{"name":<name>, "args":<args>}` body. Parses the
    //! response as JSON. Returns null on transport failure.
    var body_tab : table<string; JsonValue?>
    body_tab |> insert("name", JV(name))
    if (args != null) {
        body_tab |> insert("args", args)
    }
    let body = write_json(JV(body_tab))
    let raw = post_json(d, "/command", body)
    if (empty(raw)) {
        return null
    }
    var err : string
    return read_json(raw, err)
}

def public snapshot(d : LiveDriver) : JsonValue? {
    return post_command(d, "imgui_snapshot", null)
}

def public find_widget(var snap : JsonValue?; ident : string) : JsonValue? {
    //! Convenience navigator: `snapshot.globals[ident]`. May return a non-null
    //! `JV(null)` placeholder for missing keys (daslib/json `?[]` quirk).
    //! For an existence check use `widget_exists` instead.
    return snap?["globals"]?[ident]
}

def public widget_exists(var snap : JsonValue?; ident : string) : bool {
    //! True iff `globals[ident]` is a real widget entry. Catches the
    //! `?[]` quirk where missing object keys come back as `JV(null)` rather
    //! than a literal-null pointer — a non-null pointer to the null variant
    //! still passes `!= null`. Test for the `kind` field instead, which is
    //! always a non-empty string on a real entry.
    let kind = from_JV(snap?["globals"]?[ident]?["kind"], type<string>, "")
    return !empty(kind)
}

def public widget_payload_field(var snap : JsonValue?; ident : string; field : string) : JsonValue? {
    //! Convenience navigator: `snapshot.globals[ident].payload[field]`.
    //! Returns null if any link in the chain is missing.
    return snap?["globals"]?[ident]?["payload"]?[field]
}

def public wait_until(d : LiveDriver;
                      timeout_sec : float;
                      pred : block<(var snap : JsonValue?) : bool>) : JsonValue? {
    //! Playwright-style poll-until-condition. Calls `snapshot(d)` every
    //! `FRAME_POLL_INTERVAL_MS` and invokes `pred(snap)`; returns the first
    //! snapshot for which `pred` returns true, or null on timeout. Tests
    //! should use this (or the typed sugars below) instead of raw `sleep`s
    //! — gives auto-retry semantics, removes the brittle "give the host a
    //! frame" magic delay, and fails fast when a value never converges.
    let deadline = ref_time_ticks() + int64(timeout_sec * 1000000.0f)
    while (ref_time_ticks() < deadline) {
        var snap = snapshot(d)
        if (snap != null && invoke(pred, snap)) {
            return snap
        }
        sleep(FRAME_POLL_INTERVAL_MS)
    }
    return null
}

def public wait_for_int_value(d : LiveDriver;
                              target : string;
                              field : string;
                              expected : int;
                              timeout_sec : float = 5.0f) : bool {
    //! Poll snapshot until `globals[target].payload[field] == expected` (typed int).
    //! Returns true on match, false on timeout.
    return wait_until(d, timeout_sec) $(var snap) {
        let v = widget_payload_field(snap, target, field)
        return v != null && from_JV(v, type<int>, expected ^ 1) == expected
    } != null
}

def public wait_for_bool_value(d : LiveDriver;
                               target : string;
                               field : string;
                               expected : bool;
                               timeout_sec : float = 5.0f) : bool {
    //! Poll snapshot until `globals[target].payload[field] == expected` (typed bool).
    return wait_until(d, timeout_sec) $(var snap) {
        let v = widget_payload_field(snap, target, field)
        return v != null && from_JV(v, type<bool>, !expected) == expected
    } != null
}

def public wait_for_string_value(d : LiveDriver;
                                 target : string;
                                 field : string;
                                 expected : string;
                                 timeout_sec : float = 5.0f) : bool {
    //! Poll snapshot until `globals[target].payload[field] == expected` (typed string).
    return wait_until(d, timeout_sec) $(var snap) {
        let v = widget_payload_field(snap, target, field)
        return v != null && from_JV(v, type<string>, "") == expected
    } != null
}

def public wait_for_widget(d : LiveDriver; widget_ident : string; timeout_sec : float = DEFAULT_FRAME_WAIT_SEC) : JsonValue? {
    //! Poll snapshot until `globals.<widget_ident>` is present (i.e. at least
    //! one frame has rendered the widget). Returns the snapshot, or null on
    //! timeout. /status going 200 OK means HV is up but doesn't guarantee the
    //! GLFW window has rendered a frame yet — this is the right gate for any
    //! test asserting on widget state.
    let deadline = ref_time_ticks() + int64(timeout_sec * 1000000.0f)
    while (ref_time_ticks() < deadline) {
        var snap = snapshot(d)
        if (snap != null) {
            let globals = snap?["globals"]
            if (globals != null && globals?[widget_ident] != null) {
                return snap
            }
        }
        sleep(FRAME_POLL_INTERVAL_MS)
    }
    return null
}

def public click(d : LiveDriver; target : string) : JsonValue? {
    var args : table<string; JsonValue?>
    args |> insert("target", JV(target))
    return post_command(d, "imgui_click", JV(args))
}

def public set_value(d : LiveDriver; target : string; var value : JsonValue?) : JsonValue? {
    var args : table<string; JsonValue?>
    args |> insert("target", JV(target))
    args |> insert("value", value)
    return post_command(d, "imgui_set", JV(args))
}

def public open_widget(d : LiveDriver; target : string) : JsonValue? {
    var args : table<string; JsonValue?>
    args |> insert("target", JV(target))
    return post_command(d, "imgui_open", JV(args))
}

def public close_widget(d : LiveDriver; target : string) : JsonValue? {
    var args : table<string; JsonValue?>
    args |> insert("target", JV(target))
    return post_command(d, "imgui_close", JV(args))
}

def public reload(d : LiveDriver; timeout_sec : float = DEFAULT_RELOAD_TIMEOUT_SEC) : void {
    //! POST /reload then poll /status until has_error=false. Panics on timeout.
    post_signal(d, "/reload")
    let deadline = ref_time_ticks() + int64(timeout_sec * 1000000.0f)
    while (ref_time_ticks() < deadline) {
        let raw = get_text(d, "/status")
        if (!empty(raw)) {
            var err : string
            let parsed = read_json(raw, err)
            if (parsed != null) {
                let has_err = from_JV(parsed?["has_error"], type<bool>, false)
                if (!has_err) {
                    return
                }
            }
        }
        sleep(READY_POLL_INTERVAL_MS)
    }
    panic("reload did not converge on a clean compile within {timeout_sec}s")
}

def public with_live_app(feature_path : string; body : block<(d : LiveDriver) : void>) {
    //! Convenience form using the module-level default port + timeouts.
    //! For non-default knobs, use `with_live_app_opt`.
    with_live_app_opt(feature_path,
                      DEFAULT_LIVE_PORT,
                      DEFAULT_READY_TIMEOUT_SEC,
                      DEFAULT_TEST_TIMEOUT_SEC,
                      body)
}

def public with_live_app_opt(feature_path : string;
                             port : int;
                             ready_timeout_sec : float;
                             test_timeout_sec : float;
                             body : block<(d : LiveDriver) : void>) {
    //! Spawn daslang-live <feature_path>. Body runs while the subprocess is
    //! alive; on body return, POST /shutdown and drain stdout. Panics on
    //! non-zero exit code so the surrounding [test] surfaces the failure.
    let exe = daslang_live_exe()
    let app_path = resolve_feature_path(feature_path)
    let argv <- [exe, app_path]
    var d = LiveDriver(base_url = "http://127.0.0.1:{port}", feature_path = app_path)
    var captured : string
    var unready = false
    print("[live_driver] spawn: {exe} {app_path}\n")
    let exit_code = unsafe(popen_argv(argv, test_timeout_sec, $(f) {
        if (f == null) {
            print("[live_driver] popen returned null FILE\n")
            return
        }
        print("[live_driver] subprocess up, polling /status...\n")
        if (!wait_until_ready(d, ready_timeout_sec)) {
            print("[live_driver] readiness gate FAILED\n")
            unready = true
            captured = unsafe(fread_to_eof(f))
            return
        }
        print("[live_driver] ready, invoking body\n")
        invoke(body, d)
        print("[live_driver] body done, sending /shutdown\n")
        post_signal(d, "/shutdown")
        print("[live_driver] /shutdown posted, draining pipe...\n")
        captured = unsafe(fread_to_eof(f))
        print("[live_driver] drain done\n")
    }))
    print("[live_driver] popen exit_code={exit_code}\n")
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
