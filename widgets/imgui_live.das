options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

module imgui_live shared public

// ImGui lifecycle for daslang-live — re-exports the synth IO driver from
// imgui_live_core so consumers still `require imgui/imgui_live`.

require imgui public
require imgui_app
require glfw/glfw_boost
require daslib/archive
require daslib/clargs
require daslib/safe_addr
require live/live_commands
require live_host
require math
require strings
require imgui/imgui_boost_runtime
require imgui/imgui_live_core public
require imgui/imgui_theme_daslang

let private STORE_KEY = "__imgui_ctx"

var public live_imgui_ctx : ImGuiContext?

//! HDPI scale picked up from ``glfwGetWindowContentScale`` at init: 1.0 on a
//! plain display, 2.0 on macOS retina, 1.25/1.5/2.0 on Windows DPI scaling.
//! Set once inside :ref:`live_imgui_init <function-imgui_live_live_imgui_init>`
//! (windowed path); stays at 1.0 in headless mode. User code can read this
//! to scale custom drawing — line widths, viewport math, etc.
//!
//! Override at init by passing ``--imgui-content-scale=<float>`` after the
//! daslang ``--`` separator. Used by :ref:`with_recording_app
//! <function-imgui_playwright_with_recording_app>` to force 1x so APNG
//! captures stay small and encoder-friendly even on retina.
var public live_imgui_content_scale : float = 1.0f

// Lazy CLI-flag cache. `--imgui-content-scale=<float>` after `--` overrides
// the GLFW content-scale query in live_imgui_init. Mirrors the pattern in
// widgets/imgui_harness.das:86-101 (ensure_parsed for --headless family).
var private g_scale_parsed   : bool  = false
var private g_scale_override : float = 0.0f

def private ensure_scale_parsed() {
    return if (g_scale_parsed)
    g_scale_parsed = true
    let args <- get_user_args()
    let raw = find_flag_raw_value(args, "--imgui-content-scale")
    g_scale_override = to_float(raw |> unwrap_or("0"))
}

def public live_imgui_init(window : GLFWwindow?; glsl_version : string = "#version 330") : ImGuiContext? {
    //! Idempotent ImGui context create + backend init; safe across reload (reuses preserved ctx).
    //! Picks content scale: ``--imgui-content-scale=<float>`` override wins;
    //! otherwise queries ``glfwGetWindowContentScale``. Loads JetBrains Mono at
    //! ``14 * scale`` px, applies the daslang theme, and calls
    //! ``ScaleAllSizes(scale)`` so paddings/spacings/rounding match the display.
    //! Call from your script's ``init()``.
    if (live_imgui_ctx != null) {
        SetCurrentContext(live_imgui_ctx)
        return live_imgui_ctx
    }
    live_imgui_ctx = CreateContext(null)
    ensure_scale_parsed()
    if (g_scale_override > 0.0f) {
        live_imgui_content_scale = max(g_scale_override, 1.0f)
    } elif (window != null) {
        var xs = 1.0f
        var ys = 1.0f
        glfwGetWindowContentScale(window, safe_addr(xs), safe_addr(ys))
        // Some backends report 0 if the monitor is unavailable; clamp so
        // we never divide visual sizes to nothing.
        live_imgui_content_scale = max(max(xs, ys), 1.0f)
    }
    load_daslang_font(14.0f * live_imgui_content_scale)
    apply_daslang_theme()
    ScaleAllSizes(GetStyle(), live_imgui_content_scale)
    ImGui_ImplGlfw_InitForOpenGL(window, true)
    ImGui_ImplOpenGL3_Init(glsl_version)
    return live_imgui_ctx
}

def public live_imgui_shutdown() {
    //! Reload-aware ImGui shutdown — skips during reload so the ctx is reused, runs only on process exit. Call from your script's ``shutdown()``.
    if (live_imgui_ctx != null && !is_reload()) {
        ImGui_ImplOpenGL3_Shutdown()
        ImGui_ImplGlfw_Shutdown()
        DestroyContext(live_imgui_ctx)
        live_imgui_ctx = null
    }
}

[before_reload]
def private save_imgui_ctx() {
    if (live_imgui_ctx == null) return
    var ser = new MemSerializer()
    var arch = Archive(reading = false, stream = ser)
    var ptr_val = unsafe(reinterpret<uint64>(live_imgui_ctx))
    arch |> serialize(ptr_val)
    let data <- ser->extractData()
    live_store_bytes(STORE_KEY, data)
    unsafe { delete ser; }
}

[after_reload]
def private restore_imgui_ctx() {
    var data : array<uint8>
    if (live_load_bytes(STORE_KEY, data) && !empty(data)) {
        var ser = new MemSerializer(data)
        var arch = Archive(reading = true, stream = ser)
        var ptr_val : uint64
        arch |> serialize(ptr_val)
        unsafe {
            live_imgui_ctx = reinterpret<ImGuiContext?>(ptr_val)
            delete ser
        }
        if (live_imgui_ctx != null) {
            SetCurrentContext(live_imgui_ctx)
        }
    }
}

[init]
def private wire_glfw_real_input_toggle() {
    // boost owns set_user_control + the synth tick but is backend-agnostic. It
    // exposes register_real_input_toggle so a backend can suppress real input at
    // the source. Here the windowed GLFW backend (native imgui_app) fills it, so
    // set_user_control(false) detaches the GLFW input callbacks. Non-GLFW hosts
    // simply never register, and user control then governs only synth ownership.
    register_real_input_toggle(@@(enabled : bool) { imgui_set_real_input_callbacks(enabled); })
}
