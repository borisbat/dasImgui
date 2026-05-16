options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options _allow_imgui_legacy = true
// Defensive opt-out: the harness is the legitimate caller into glfw/opengl/
// imgui_live backends — its own compile passes need to skip its own lint.
// Same pattern as `_allow_imgui_legacy = true` on widgets/imgui_lint.das.
options _allow_glfw_calls = true

module imgui_harness shared public

//! Canonical wrapper for dasImgui examples and tests.
//!
//! Hides the GLFW/OpenGL backend boilerplate behind five helpers
//! (``harness_init`` / ``harness_begin_frame`` / ``harness_new_frame`` /
//! ``harness_end_frame`` / ``harness_shutdown``, plus optional
//! ``harness_apply_synth_io``). Examples ``require imgui_harness`` and never
//! touch GLFW/GL symbols directly.
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
require opengl/opengl_boost
require live/glfw_live
require live/opengl_live

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
require imgui/imgui_colors public
require imgui/imgui_visual_aids

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
var private g_parsed            : bool = false

var private g_headless_ctx      : ImGuiContext? = null
var private g_headless_frame    : int = 0
var private g_headless_dt       : float = 1.0f / 60.0f
var private g_headless_last_uptime : float = -1.0f

def private ensure_parsed() {
    // Lazy CLI parse on first harness_* call. clargs `find_*` helpers don't
    // error on unknown args, so future test-side clargs structs coexist.
    return if (g_parsed)
    g_parsed = true
    let args <- get_user_args()
    print("[harness] ensure_parsed: get_user_args() length={length(args)}\n")
    for (a in args) {
        print("[harness] ensure_parsed:   arg: {a}\n")
    }
    let raw_headless = find_bool_flag_raw_value(args, "--headless")
    g_headless = (raw_headless |> unwrap_or("false")) == "true"
    let raw_frames = find_flag_raw_value(args, "--headless-frames")
    g_headless_max_frames = to_int(raw_frames |> unwrap_or("0"))
    print("[harness] ensure_parsed: g_headless={g_headless}\n")
}

def private log_arm(name : string) {
    let arm = g_headless ? "headless" : "windowed"
    print("[harness] {name}: arm={arm}\n")
}

def public harness_is_headless() : bool {
    //! True if ``--headless`` was on the command line. Stable across the process.
    ensure_parsed()
    return g_headless
}

def public harness_init(title : string; width : int = 800; height : int = 600) {
    //! Windowed: ``live_create_window`` + ``live_imgui_init``. Headless:
    //! ``CreateContext`` + ``StyleColorsDark`` + font atlas build +
    //! ``DisplaySize`` — no window, no GL context.
    log_arm("harness_init")
    if (harness_is_headless()) {
        print("[harness] harness_init headless: CreateContext\n")
        g_headless_ctx = CreateContext(null)
        print("[harness] harness_init headless: StyleColorsDark\n")
        StyleColorsDark(null)
        print("[harness] harness_init headless: imgui_headless_init_fonts\n")
        imgui_headless_init_fonts()
        print("[harness] harness_init headless: imgui_headless_set_display_size\n")
        imgui_headless_set_display_size(float(width), float(height))
        print("[harness] harness_init headless: DONE\n")
        return
    }
    print("[harness] harness_init windowed: live_create_window\n")
    live_create_window(title, width, height)
    print("[harness] harness_init windowed: live_imgui_init\n")
    live_imgui_init(live_window)
    print("[harness] harness_init windowed: DONE\n")
}

def public harness_begin_frame() : bool {
    //! Returns false to skip update (window closed in windowed mode; auto-exit
    //! cap reached in headless). Windowed: ``live_begin_frame`` + ``begin_frame``
    //! + ``Impl_OpenGL3_NewFrame`` + ``Impl_Glfw_NewFrame``. Headless:
    //! ``begin_frame`` + ``imgui_headless_advance_dt`` (real wall-clock dt).
    if (g_headless_frame < 3) {
        print("[harness] harness_begin_frame: entry frame={g_headless_frame}\n")
    }
    if (harness_is_headless()) {
        if (g_headless_max_frames > 0 && g_headless_frame >= g_headless_max_frames) {
            request_exit()
            return false
        }
        let now = get_uptime()
        if (g_headless_last_uptime >= 0.0f) {
            let dt = now - g_headless_last_uptime
            g_headless_dt = dt > 0.0f ? dt : (1.0f / 60.0f)
        }
        g_headless_last_uptime = now
        if (g_headless_frame < 3) {
            print("[harness] harness_begin_frame headless: imgui_headless_advance_dt dt={g_headless_dt}\n")
        }
        imgui_headless_advance_dt(g_headless_dt)
        if (g_headless_frame < 3) {
            print("[harness] harness_begin_frame headless: begin_frame()\n")
        }
        begin_frame()
        g_headless_frame++
        if (g_headless_frame <= 3) {
            print("[harness] harness_begin_frame headless: returning true, frame now {g_headless_frame}\n")
        }
        return true
    }
    return false if (!live_begin_frame())
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    return true
}

def public harness_apply_synth_io() {
    //! Optional — call between ``harness_begin_frame`` and ``harness_new_frame``
    //! when the test drives synthetic IO via the ``imgui_*`` ``[live_command]``
    //! family (``imgui_mouse_play``, ``imgui_key_chord``, …). Windowed:
    //! re-asserts synth pos so it wins the GLFW backend's per-frame poll race.
    //! Headless: drains the same synth timeline (no backend to race with, but
    //! held state still needs the per-frame tick).
    apply_synth_io_override()
}

def public harness_new_frame() {
    //! ``ImGui::NewFrame()``. Identical in both modes.
    NewFrame()
}

def public harness_end_frame() {
    //! Windowed: ``end_of_frame`` + ``Render`` + viewport/clear +
    //! ``Impl_OpenGL3_RenderDrawData`` + ``live_end_frame``. Headless:
    //! ``end_of_frame`` + ``Render`` (DrawData discarded; no GL output).
    if (harness_is_headless()) {
        end_of_frame()
        Render()
        return
    }
    end_of_frame()
    Render()
    var w, h : int
    live_get_framebuffer_size(w, h)
    glViewport(0, 0, w, h)
    glClearColor(0.10f, 0.10f, 0.12f, 1.0f)
    glClear(GL_COLOR_BUFFER_BIT)
    ImGui_ImplOpenGL3_RenderDrawData(GetDrawData())
    live_end_frame()
}

def public harness_shutdown() {
    //! Windowed: ``live_imgui_shutdown`` + ``live_destroy_window``.
    //! Headless: ``DestroyContext`` (the harness owns the ctx in headless mode).
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
