options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options _allow_imgui_legacy = true
// Defensive opt-out: the harness is the legitimate caller into glfw/opengl/
// imgui_live backends — its own compile passes need to skip its own lint.
// Same pattern as `_allow_imgui_legacy = true` on widgets/imgui_lint.das.
options _allow_glfw_calls = true
options persistent_heap   // collectable heap so per-frame JsonValue churn is reclaimed; unifies program-wide

module imgui_harness shared public

//! Canonical wrapper for dasImgui examples and tests.
//!
//! Hides the GLFW/OpenGL backend boilerplate behind five helpers
//! (``harness_init`` / ``harness_begin_frame`` / ``harness_new_frame`` /
//! ``harness_end_frame`` / ``harness_shutdown``). ``harness_new_frame`` runs the
//! boost synth tick automatically, so synthetic input works with no opt-in.
//! Examples ``require imgui_harness`` and never touch GLFW/GL symbols directly.
//!
//! Mode dispatch (windowed vs headless) is internal. Pass ``--headless`` after
//! the daslang ``--`` separator to run without a window:
//! ``daslang FILE.das -- --headless``. Add ``--headless-frames=N`` to auto-exit
//! after ``N`` frames (default 0 = run until ``request_exit()``); useful for
//! CI smoke runs that have no out-of-band exit signal.
//!
//! Re-exports the backend-agnostic dasImgui stack so consumers need only a
//! single ``require imgui_harness`` line.

// NOTE on require ordering: the windowed backend (imgui_app + glfw/opengl)
// must be required BEFORE the live_api / live_commands family. Reordering
// these tickles a daslang-live readiness regression where /status never
// returns 200 to a popen parent — likely a [_macro]-driven debug-agent
// install racing with GLFW backend init. The harness mirrors the canonical
// order used by every pre-harness example/test verbatim.

// Windowed backend (must come first; see ordering note above).
require imgui public
require imgui_app
require glfw/glfw_boost
require opengl/opengl
require live/glfw_live
require live/opengl_live // nolint:STYLE030 — loads the APNG recorder (record_* live commands + the [before_update] record_tick) by side effect; no direct symbol use

// Live-host + boost-runtime stack — re-exported public.
require live/live_api public
require live/live_commands public
require live/live_vars public
require live_host public
require imgui/imgui_live
require imgui/imgui_boost_runtime public
require imgui/imgui_boost_v2 public
require imgui/imgui_widgets_builtin public
require imgui/imgui_containers_builtin public
require imgui/imgui_scope_builtin public
require imgui/imgui_id_builtin public
require imgui/imgui_style_builtin public
require imgui/imgui_layout_builtin public
require imgui/imgui_docking_builtin public
require imgui/imgui_drawlist_builtin public
require imgui/imgui_colors public
require imgui/imgui_visual_aids
require imgui/imgui_theme_daslang

// Headless backend — private. 3-fn surface (no GLFW/GL names).
require imgui_app_headless

// Default-on lint — public re-export so every consumer file picks it up.
// Forbids direct windowed-backend calls in harness-using files. Opt-out:
// `options _allow_glfw_calls = true` (scaffolding only).
require imgui/imgui_harness_lint public

require daslib/clargs
require strings

var private g_headless          : bool = false
var private g_headless_max_frames : int = 0
var private g_headless_max_uptime_sec : float = 0.0f
var private g_no_ini            : bool = false
var private g_parsed            : bool = false

var private g_headless_ctx      : ImGuiContext? = null
var private g_headless_frame    : int = 0
var private g_headless_dt       : float = 1.0f / 60.0f
var private g_headless_last_uptime : float = -1.0f
var private g_headless_first_uptime : float = -1.0f

def private ensure_parsed() {
    // Lazy CLI parse on first harness_* call. clargs `find_*` helpers don't
    // error on unknown args, so future test-side clargs structs coexist.
    return if (g_parsed)
    g_parsed = true
    let args <- get_user_args()
    g_no_ini = (find_bool_flag_raw_value(args, "--no-imgui-ini") |> unwrap_or("false")) == "true"
    let raw_headless = find_bool_flag_raw_value(args, "--headless")
    g_headless = (raw_headless |> unwrap_or("false")) == "true"
    let raw_frames = find_flag_raw_value(args, "--headless-frames")
    g_headless_max_frames = to_int(raw_frames |> unwrap_or("0"))
    // Wall-clock self-exit timer. 0 = disabled (preserves standalone usage).
    // Playwright passes a value < its popen watchdog so a panicked test still
    // releases the live-API port before the parent gives up (cascade guard).
    let raw_timeout = find_flag_raw_value(args, "--headless-timeout-sec")
    g_headless_max_uptime_sec = to_float(raw_timeout |> unwrap_or("0"))
}

def public harness_is_headless() : bool {
    //! True if ``--headless`` was on the command line. Stable across the process.
    ensure_parsed()
    return g_headless
}

def public harness_wants_no_ini() : bool {
    //! True if ``--no-imgui-ini`` was on the command line (``with_imgui_app``
    //! passes it for every test spawn). ``harness_init`` calls
    //! ``DisableIniPersistence`` when set, so ImGui never loads or saves
    //! imgui.ini. Apps that gate default-layout setup on ``fexist("imgui.ini")``
    //! must also check this: with persistence off, ImGui restores nothing, so a
    //! stale imgui.ini on disk is NOT a reason to skip building the default layout.
    ensure_parsed()
    return g_no_ini
}

def public harness_init(title : string; width : int = 800; height : int = 600) {
    //! Windowed: ``live_create_window`` + ``live_imgui_init`` (which also applies
    //! the daslang theme + JetBrains Mono font). Headless: ``CreateContext`` +
    //! ``apply_daslang_theme`` + font atlas build + ``DisplaySize`` — no window,
    //! no GL context, no TTF (the headless atlas uses ProggyClean).
    if (harness_is_headless()) {
        g_headless_ctx = CreateContext(null)
        apply_daslang_theme()
        imgui_headless_init_fonts()
        imgui_headless_set_display_size(float(width), float(height))
        if (g_no_ini) {
            DisableIniPersistence()
        }
        return
    }
    // Opt into per-monitor DPI on Windows so glfwCreateWindow scales the
    // requested size by the monitor scale (no-op on macOS/Linux, where
    // the windowing system already handles it). live_imgui_init then
    // reads glfwGetWindowContentScale and applies it to fonts + theme.
    glfwWindowHint(int(GLFW_SCALE_TO_MONITOR), 1)
    live_create_window(title, width, height)
    live_imgui_init(live_window)
    // --no-imgui-ini (with_imgui_app passes it for every test spawn): null the
    // ini AFTER live_imgui_init creates the context, BEFORE the first NewFrame,
    // so a windowed GL test starts from the app's default layout and never
    // reads/writes a stale imgui.ini in the spawn CWD.
    if (g_no_ini) {
        DisableIniPersistence()
    }
}

def public harness_begin_frame() : bool {
    //! Returns false to skip update (window closed in windowed mode; auto-exit
    //! cap reached in headless). Windowed: ``live_begin_frame`` + ``begin_frame``
    //! + ``Impl_OpenGL3_NewFrame`` + ``Impl_Glfw_NewFrame``. Headless:
    //! ``begin_frame`` + ``imgui_headless_advance_dt`` (real wall-clock dt).
    if (harness_is_headless()) {
        if (g_headless_max_frames > 0 && g_headless_frame >= g_headless_max_frames) {
            request_exit()
            return false
        }
        let now = get_uptime()
        if (g_headless_first_uptime < 0.0f) {
            g_headless_first_uptime = now
        }
        if (g_headless_max_uptime_sec > 0.0f && (now - g_headless_first_uptime) >= g_headless_max_uptime_sec) {
            // Cascade-guard fire — kept on stdout because it's diagnostic
            // (only emitted when the safety net actually trips, never in healthy runs).
            print("[harness] headless timeout {g_headless_max_uptime_sec}s reached at uptime {now - g_headless_first_uptime}s — request_exit()\n")
            request_exit()
            return false
        }
        if (g_headless_last_uptime >= 0.0f) {
            let dt = now - g_headless_last_uptime
            g_headless_dt = dt > 0.0f ? dt : (1.0f / 60.0f)
        }
        g_headless_last_uptime = now
        imgui_headless_advance_dt(g_headless_dt)
        begin_frame()
        g_headless_frame++
        advance_coroutines()
        return true
    }
    return false if (!live_begin_frame())
    begin_frame()
    // (no ImGui_ImplOpenGL3_NewFrame — the das renderer builds its objects at init, nothing per-frame)
    ImGui_ImplGlfw_NewFrame()
    // Single clock: drive ImGui DeltaTime from the master clock (get_dt), so lockstep
    // recording uses the fixed step; normal mode get_dt()==wall dt (no-op). Guard >0.
    let mdt = get_dt()
    if (mdt > 0.0f) {
        var io & = unsafe(GetIO())
        io.DeltaTime = mdt
    }
    advance_coroutines()
    return true
}

def public harness_new_frame() {
    //! Runs the boost synth tick — so synthetic mouse/keyboard and ``set_user_control``
    //! work on every harness app with no opt-in — then ``ImGui::NewFrame()``. The tick
    //! sits between the backend's ``*_NewFrame()`` (in ``harness_begin_frame``) and
    //! ``NewFrame()`` here, the slot synthetic input must drain in. Both modes.
    imgui_synth_tick()
    NewFrame()
}

def public harness_end_frame() {
    //! Windowed: ``end_of_frame`` + ``Render`` + viewport/clear +
    //! ``Impl_OpenGL3_RenderDrawData`` + ``live_end_frame``. Headless:
    //! ``end_of_frame`` + ``Render`` (DrawData discarded; no GL output).
    if (harness_is_headless()) {
        end_of_frame()
        Render()
        // drain the backend texture queue with fake IDs (no GPU backend in
        // headless) so texture-status assertions pass next frame.
        imgui_headless_process_textures()
        return
    }
    end_of_frame()
    Render()
    var w, h : int
    live_get_framebuffer_size(w, h)
    glViewport(0, 0, w, h)
    glClearColor(0.10f, 0.10f, 0.12f, 1.0f)
    glClear(GL_COLOR_BUFFER_BIT)
    live_imgui_render()
    live_end_frame()
}

def public harness_shutdown() {
    //! Windowed: ``live_imgui_shutdown`` + ``live_destroy_window``.
    //! Headless: ``DestroyContext`` (the harness owns the ctx in headless mode).
    // Final GC-pressure summary (no-op unless imgui_debug_memory was enabled). Runs
    // before context teardown so the numbers reflect the steady-state app, not cleanup.
    imgui_memory_report()
    if (harness_is_headless()) {
        if (g_headless_ctx != null) {
            DestroyContext(g_headless_ctx)
            g_headless_ctx = null
        }
        return
    }
    live_imgui_shutdown()
    live_destroy_window()
}

def public harness_frame_count() : int {
    //! Headless-mode frame counter (incremented inside ``harness_begin_frame``).
    //! Returns 0 in windowed mode — windowed frame count is the ImGui core
    //! ``GetFrameCount()``.
    return g_headless_frame
}
