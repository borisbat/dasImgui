options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false
options _allow_imgui_legacy = true

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
//! ``daslang FILE.das -- --headless``. Headless mode is wired in PR 2 — until
//! then, ``--headless`` triggers a panic with a clear "land PR 2 first"
//! message; windowed mode is fully functional.
//!
//! Re-exports the backend-agnostic dasImgui stack so consumers need only a
//! single ``require imgui_harness`` line.

// Backend-agnostic stack — re-exported public.
require imgui public
require imgui/imgui_boost_v2 public
require imgui/imgui_boost_runtime public
require imgui/imgui_widgets_builtin public
require imgui/imgui_containers_builtin public
require live/live_api public
require live/live_commands public
require live/live_vars public
require live_host public

// Windowed backend — private. Lint (PR 3) forbids user-scope leakage.
require imgui_app
require glfw/glfw_boost
require opengl/opengl_boost
require live/glfw_live
require live/opengl_live
require imgui/imgui_live
require imgui/imgui_visual_aids

require daslib/clargs

var private g_headless : bool = false
var private g_parsed : bool = false

def private ensure_parsed() {
    // Lazy CLI parse on first harness_* call. clargs `find_bool_flag_raw_value`
    // doesn't error on unknown args, so future test-side clargs structs coexist.
    if (g_parsed) return
    g_parsed = true
    let args <- get_user_args()
    let raw = find_bool_flag_raw_value(args, "--headless")
    g_headless = (raw |> unwrap_or("false")) == "true"
}

def private panic_pr1_headless() {
    panic("imgui_harness: --headless is not yet implemented (land PR 2 first)")
}

def public harness_is_headless() : bool {
    //! True if ``--headless`` was on the command line. Stable across the process.
    ensure_parsed()
    return g_headless
}

def public harness_init(title : string; width : int = 800; height : int = 600) {
    //! Windowed: ``live_create_window`` + ``live_imgui_init``. Headless (PR 2+):
    //! ``CreateContext`` + ``Fonts->Build`` + ``DisplaySize``, no window.
    if (harness_is_headless()) {
        panic_pr1_headless()
        return
    }
    live_create_window(title, width, height)
    live_imgui_init(live_window)
}

def public harness_begin_frame() : bool {
    //! Returns false to skip update (window closed). Windowed: ``live_begin_frame``
    //! + ``begin_frame`` + ``Impl_OpenGL3_NewFrame`` + ``Impl_Glfw_NewFrame``.
    //! Headless (PR 2+): ``begin_frame`` + ``io.DeltaTime`` advance.
    if (harness_is_headless()) {
        panic_pr1_headless()
        return false
    }
    if (!live_begin_frame()) return false
    begin_frame()
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    return true
}

def public harness_apply_synth_io() {
    //! Optional — call between ``harness_begin_frame`` and ``harness_new_frame``
    //! when the test drives synthetic IO. Windowed: ``apply_synth_io_override``
    //! (wins the GLFW backend race). Headless (PR 2+): no-op.
    return if (harness_is_headless())
    apply_synth_io_override()
}

def public harness_new_frame() {
    //! ``ImGui::NewFrame()``. Identical in both modes.
    NewFrame()
}

def public harness_end_frame() {
    //! Windowed: ``end_of_frame`` + ``Render`` + viewport/clear +
    //! ``Impl_OpenGL3_RenderDrawData`` + ``live_end_frame``. Headless (PR 2+):
    //! ``end_of_frame`` + ``Render`` (DrawData discarded).
    if (harness_is_headless()) {
        panic_pr1_headless()
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
    //! Headless (PR 2+): ``DestroyContext``.
    if (harness_is_headless()) {
        panic_pr1_headless()
        return
    }
    live_imgui_shutdown()
    live_destroy_window()
}
