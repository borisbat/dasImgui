options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module imgui_transport shared public

require dashv/dashv_boost public
require daslib/json public
require daslib/json_boost public
require daslib/fio

// Module overview lives in handmade/module-imgui_transport.rst.
// Wait helpers are client-side only — server-side blocking would deadlock
// the GLFW main thread, which also advances frames.

typedef Transport = lambda<(action : string; var payload : JsonValue?) : JsonValue?>

let DEFAULT_AWAIT_POLL_MS : uint = 50u
let DEFAULT_AWAIT_TIMEOUT_SEC : float = 5.0f

def public live_api_transport(url : string) : Transport {
    //! Default transport: POSTs ``{"name": action, "args": payload}`` to ``<url>/command`` and parses the JSON response. ``url`` is captured by value, so the returned lambda is safe to reuse.
    return <- @ capture(= url) (action : string; var payload : JsonValue ?) : JsonValue ? {
        var body_tab : table<string; JsonValue?>
        body_tab |> insert("name", JV(action))
        if (payload != null) {
            body_tab |> insert("args", payload)
        }
        let body = write_json(JV(body_tab))
        var out : string
        POST("{url}/command", body, {"Content-Type" => "application/json"}) $(resp) {
            if (resp != null) {
                out = string(resp.body)
            }
        }
        if (empty(out)) return null
        var err_str : string
        return read_json(out, err_str)
    }
}

def public send_imgui_command(transport : Transport; action : string; var payload : JsonValue?) : JsonValue? {
    //! Send one command through ``transport`` and return the parsed JSON response.
    return invoke(transport, action, payload)
}

def public receive_imgui_snapshot(transport : Transport) : JsonValue? {
    //! Convenience for ``send_imgui_command(transport, "imgui_snapshot", null)`` — fetches the full widget snapshot.
    return invoke(transport, "imgui_snapshot", null)
}

def public await_imgui(transport : Transport;
                       until : string = "quiescent";
                       timeout_sec : float = DEFAULT_AWAIT_TIMEOUT_SEC) : bool {
    //! Poll ``imgui_await`` until ``value.quiescent`` flips true; returns true on quiescence, false on timeout.
    let deadline = ref_time_ticks() + int64(double(timeout_sec) * 1000000.0lf)
    var args_jv = JV((until = until))
    while (ref_time_ticks() < deadline) {
        let r = invoke(transport, "imgui_await", args_jv)
        if (r?["value"]?["quiescent"] ?? false) return true
        sleep(DEFAULT_AWAIT_POLL_MS)
    }
    return false
}

def public await_imgui_frame(transport : Transport;
                             target_frame : int;
                             timeout_sec : float = DEFAULT_AWAIT_TIMEOUT_SEC) : bool {
    //! Poll ``imgui_await`` until server-side ``value.frame >= target_frame``; reuses the ``frame:`` arg so server flips ``quiescent`` at the right tick.
    let deadline = ref_time_ticks() + int64(double(timeout_sec) * 1000000.0lf)
    var args_jv = JV((frame = target_frame))
    while (ref_time_ticks() < deadline) {
        let r = invoke(transport, "imgui_await", args_jv)
        if (r?["value"]?["quiescent"] ?? false) return true
        sleep(DEFAULT_AWAIT_POLL_MS)
    }
    return false
}

def public send_with_await(transport : Transport;
                           action : string;
                           var payload : JsonValue?;
                           timeout_sec : float = DEFAULT_AWAIT_TIMEOUT_SEC) : JsonValue? {
    //! Send ``action``/``payload`` and honor any ``await_*`` modifier the server merged into the response.
    //! Dispatches on ``await_frames`` / ``await_until: "quiescent"`` / ``fire_and_forget``; otherwise default-polls quiescence with ``timeout_sec``.
    var r = invoke(transport, action, payload)
    if (r == null) return null
    let af = r?["await_frames"]
    if (af != null) {
        let n = af ?? 0
        let base_frame = r?["value"]?["frame"] ?? 0
        let _ = await_imgui_frame(transport, base_frame + n, timeout_sec)
        return r
    }
    let au = r?["await_until"]
    if ((au ?? "") == "quiescent") {
        let _ = await_imgui(transport, "quiescent", timeout_sec)
        return r
    }
    let ts = r?["timeout_sec"]
    if (ts != null) {
        let _ = await_imgui(transport, "quiescent", timeout_sec)
    }
    return r
}
