options gen2
options indenting = 4
options no_unused_block_arguments = false
options no_unused_function_arguments = false

require dastest/testing_boost public
require imgui/imgui_playwright public
require daslib/json public
require daslib/json_boost public

//! Exercises the wait-family auto-dump (``set_auto_dump_on_timeout``, default on): any
//! ``wait_*`` helper that times out logs the live UI state once via ``log_snapshot`` before
//! returning null/false, so a red headless / slow-CI run is self-explaining with zero
//! per-test dump code.
//!
//! The test deliberately waits for a widget that never exists, so the wait genuinely times
//! out — the assertion (it returned null) PASSES, and the auto-dump fires as the visible side
//! effect (look for "log_snapshot [wait timeout: wait_for_widget ...]" in this test's log). It
//! also confirms the toggle: with auto-dump off the same wait still times out, just silently.
//! Runs headless on ubuntu + macOS like the rest of the integration suite.

let TRIGGERS_FEATURE = "modules/dasImgui/examples/features/triggers.das"
let ABSENT = "MAIN_WIN/NO_SUCH_WIDGET"

[test]
def test_auto_dump_on_timeout(t : T?) {
    with_imgui_app(TRIGGERS_FEATURE) $(d) {
        // boot: a real widget renders, so the snapshot has a registry to dump
        t |> success(wait_for_widget(d, "MAIN_WIN/SAVE_BTN", 15.0f) != null, "demo booted (MAIN_WIN/SAVE_BTN)")

        // default: auto-dump is on
        t |> success(auto_dump_on_timeout_enabled(), "auto-dump defaults to on")

        // deliberately time out on an absent widget — auto-dumps the UI state to the log
        t |> success(wait_for_widget(d, ABSENT, 1.5f) == null,
            "wait_for_widget on an absent widget times out (and auto-dumps the live UI state above)")

        // toggle off: the same wait still times out, just without the dump
        set_auto_dump_on_timeout(false)
        t |> success(!auto_dump_on_timeout_enabled(), "set_auto_dump_on_timeout(false) flips the flag")
        t |> success(wait_for_widget(d, ABSENT, 1.0f) == null, "wait still times out with auto-dump off (silently)")
        set_auto_dump_on_timeout(true)
        t |> success(auto_dump_on_timeout_enabled(), "restored to on")
    }
}
